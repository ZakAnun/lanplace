import { bytesToHex } from '../../../shared/ble/BytesHex';
import { BleGattSession } from '../domain/BleGattSession';
import { GattCharacteristicNode, GattServiceNode, GattValueEvent, GattValueListener } from '../domain/GattProfile';
import { GattWriteQueue } from '../domain/GattWriteQueue';
import {
  GATT_CONNECT_TIMEOUT_MS,
  GATT_ERROR_TIMEOUT,
  GattFacadeApi,
  GattOperationError,
  asGattOperationError
} from '../domain/GattFacade';
import { GattConnectionRegistry } from './GattConnectionRegistry';
import { GattClock, IGattTransport, SystemGattClock } from './IGattTransport';
import { LogEvent, LogEventDomain } from '../../session-log/domain/LogEvent';
import { LogEventType } from '../../session-log/domain/LogEventType';
import { LogEventBus } from '../../session-log/domain/LogEventBus';

function bleDeviceKey(deviceId: string): string {
  return `ble:${deviceId}`;
}

function connectWithDeadline(
  work: Promise<string[]>,
  timeoutMs: number,
  clock: GattClock,
  onTimeout: () => void
): Promise<string[]> {
  return new Promise<string[]>((resolve: (uuids: string[]) => void, reject: (err: GattOperationError) => void): void => {
    let settled: boolean = false;
    const timerId: number = clock.schedule(timeoutMs, (): void => {
      if (settled) {
        return;
      }
      settled = true;
      onTimeout();
      reject(new GattOperationError(GATT_ERROR_TIMEOUT, 'connect timeout'));
    });
    work.then((uuids: string[]): void => {
      if (settled) {
        return;
      }
      settled = true;
      clock.cancel(timerId);
      resolve(uuids);
    }).catch((err: Object): void => {
      if (settled) {
        return;
      }
      settled = true;
      clock.cancel(timerId);
      reject(asGattOperationError(err));
    });
  });
}

function subscriptionKey(deviceId: string, serviceUuid: string, characteristicUuid: string): string {
  return `${deviceId}|${serviceUuid}|${characteristicUuid}`;
}

export class DefaultGattFacade implements GattFacadeApi {
  private readonly transport: IGattTransport;
  private readonly clock: GattClock;
  private readonly listeners: GattValueListener[] = [];
  private readonly writeQueues: Map<string, GattWriteQueue> = new Map();
  private readonly subscriptions: Map<string, boolean> = new Map();

  constructor(transport: IGattTransport, clock?: GattClock) {
    this.transport = transport;
    this.clock = clock !== undefined ? clock : new SystemGattClock();
    this.transport.onCharacteristicValue((event: GattValueEvent): void => {
      this.append(
        event.deviceId,
        LogEventType.GATT_NOTIFY,
        `${event.characteristicUuid} ${bytesToHex(event.value)}`
      );
      for (let i = 0; i < this.listeners.length; i++) {
        this.listeners[i](event);
      }
    });
  }

  async connect(deviceId: string): Promise<void> {
    const connecting: BleGattSession = {
      deviceId: deviceId,
      phase: 'Connecting'
    };
    GattConnectionRegistry.register(connecting);
    try {
      const services: string[] = await connectWithDeadline(
        this.transport.connect(deviceId),
        GATT_CONNECT_TIMEOUT_MS,
        this.clock,
        (): void => {
          this.transport.cancelConnect(deviceId);
        }
      );
      const profile: GattServiceNode[] = this.transport.services(deviceId);
      const connected: BleGattSession = {
        deviceId: deviceId,
        phase: 'Connected',
        services: services,
        profile: profile
      };
      GattConnectionRegistry.register(connected);
      this.append(deviceId, LogEventType.GATT_CONNECT, 'connected');
    } catch (err) {
      const gattErr: GattOperationError = asGattOperationError(err as Object);
      GattConnectionRegistry.setPhase(deviceId, 'Disconnected');
      this.append(deviceId, LogEventType.GATT_ERROR, `code=${gattErr.code}`);
      throw gattErr;
    }
  }

  async disconnect(deviceId: string): Promise<void> {
    await this.transport.disconnect(deviceId);
    GattConnectionRegistry.setPhase(deviceId, 'Disconnected');
    this.append(deviceId, LogEventType.GATT_DISCONNECT, 'disconnected');
  }

  isConnected(deviceId: string): boolean {
    const found: BleGattSession | null = GattConnectionRegistry.get(deviceId);
    if (found === null) {
      return false;
    }
    return found.phase === 'Connected';
  }

  connectedDeviceIds(): string[] {
    return GattConnectionRegistry.connectedDeviceIds();
  }

  profile(deviceId: string): GattServiceNode[] {
    const found: BleGattSession | null = GattConnectionRegistry.get(deviceId);
    if (found === null || found.profile === undefined) {
      const empty: GattServiceNode[] = [];
      return empty;
    }
    return found.profile;
  }

  async readCharacteristicValue(
    deviceId: string,
    serviceUuid: string,
    characteristicUuid: string
  ): Promise<Uint8Array> {
    try {
      return await this.transport.readCharacteristicValue(deviceId, serviceUuid, characteristicUuid);
    } catch (err) {
      const gattErr: GattOperationError = asGattOperationError(err as Object);
      this.append(deviceId, LogEventType.GATT_ERROR, `code=${gattErr.code} read ${characteristicUuid}`);
      throw gattErr;
    }
  }

  writeCharacteristicValue(
    deviceId: string,
    serviceUuid: string,
    characteristicUuid: string,
    value: Uint8Array
  ): Promise<void> {
    const writeNoResponse: boolean = this.useWriteNoResponse(deviceId, serviceUuid, characteristicUuid);
    return this.queueFor(deviceId).enqueue((): Promise<void> => {
      return this.transport.writeCharacteristicValue(
        deviceId,
        serviceUuid,
        characteristicUuid,
        value,
        writeNoResponse
      ).then((): void => {
        return;
      }, (err: Object): Promise<void> => {
        const gattErr: GattOperationError = asGattOperationError(err);
        this.append(deviceId, LogEventType.GATT_ERROR, `code=${gattErr.code} write ${characteristicUuid}`);
        return Promise.reject(gattErr);
      });
    });
  }

  async setCharacteristicChangeNotification(
    deviceId: string,
    serviceUuid: string,
    characteristicUuid: string,
    enable: boolean
  ): Promise<void> {
    const indicate: boolean = this.useIndicate(deviceId, serviceUuid, characteristicUuid);
    try {
      await this.transport.setCharacteristicChangeNotification(
        deviceId,
        serviceUuid,
        characteristicUuid,
        enable,
        indicate
      );
      this.rememberSubscription(deviceId, serviceUuid, characteristicUuid, enable);
    } catch (err) {
      const gattErr: GattOperationError = asGattOperationError(err as Object);
      this.append(deviceId, LogEventType.GATT_ERROR, `code=${gattErr.code} notify ${characteristicUuid}`);
      throw gattErr;
    }
  }

  isSubscribed(deviceId: string, serviceUuid: string, characteristicUuid: string): boolean {
    const found: boolean | undefined = this.subscriptions.get(subscriptionKey(deviceId, serviceUuid, characteristicUuid));
    return found === true;
  }

  subscribeValues(listener: GattValueListener): void {
    this.listeners.push(listener);
  }

  unsubscribeValues(listener: GattValueListener): void {
    const next: GattValueListener[] = [];
    for (let i = 0; i < this.listeners.length; i++) {
      if (this.listeners[i] !== listener) {
        next.push(this.listeners[i]);
      }
    }
    this.listeners.length = 0;
    for (let i = 0; i < next.length; i++) {
      this.listeners.push(next[i]);
    }
  }

  private rememberSubscription(
    deviceId: string,
    serviceUuid: string,
    characteristicUuid: string,
    enable: boolean
  ): void {
    const key: string = subscriptionKey(deviceId, serviceUuid, characteristicUuid);
    if (enable) {
      this.subscriptions.set(key, true);
      return;
    }
    this.subscriptions.delete(key);
  }

  private queueFor(deviceId: string): GattWriteQueue {
    const found: GattWriteQueue | undefined = this.writeQueues.get(deviceId);
    if (found !== undefined) {
      return found;
    }
    const created: GattWriteQueue = new GattWriteQueue();
    this.writeQueues.set(deviceId, created);
    return created;
  }

  private findCharacteristic(
    deviceId: string,
    serviceUuid: string,
    characteristicUuid: string
  ): GattCharacteristicNode | null {
    const profile: GattServiceNode[] = this.profile(deviceId);
    for (let i = 0; i < profile.length; i++) {
      if (profile[i].serviceUuid !== serviceUuid) {
        continue;
      }
      const chars: GattCharacteristicNode[] = profile[i].characteristics;
      for (let j = 0; j < chars.length; j++) {
        if (chars[j].characteristicUuid === characteristicUuid) {
          return chars[j];
        }
      }
    }
    return null;
  }

  private useWriteNoResponse(deviceId: string, serviceUuid: string, characteristicUuid: string): boolean {
    const node: GattCharacteristicNode | null = this.findCharacteristic(deviceId, serviceUuid, characteristicUuid);
    if (node === null || node.canWrite) {
      return false;
    }
    return node.canWriteNoResponse;
  }

  private useIndicate(deviceId: string, serviceUuid: string, characteristicUuid: string): boolean {
    const node: GattCharacteristicNode | null = this.findCharacteristic(deviceId, serviceUuid, characteristicUuid);
    if (node === null) {
      return false;
    }
    return node.canIndicate && !node.canNotify;
  }

  private append(deviceId: string, type: string, message: string): void {
    const domainBle: LogEventDomain = 'ble';
    const event: LogEvent = {
      ts: Date.now(),
      deviceKey: bleDeviceKey(deviceId),
      domain: domainBle,
      type: type,
      message: message
    };
    LogEventBus.append(event);
  }
}
