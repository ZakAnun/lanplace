import { BleGattSession } from '../domain/BleGattSession';
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

export class DefaultGattFacade implements GattFacadeApi {
  private readonly transport: IGattTransport;
  private readonly clock: GattClock;

  constructor(transport: IGattTransport, clock?: GattClock) {
    this.transport = transport;
    this.clock = clock !== undefined ? clock : new SystemGattClock();
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
      const connected: BleGattSession = {
        deviceId: deviceId,
        phase: 'Connected',
        services: services
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
