import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { bytesToHex, hexToBytes } from '../main/ets/shared/ble/BytesHex';
import { BleGattSession } from '../main/ets/features/gatt/domain/BleGattSession';
import { GattFacade, GattOperationError, gattErrorCode } from '../main/ets/features/gatt/domain/GattFacade';
import {
  GattCharacteristicNode,
  GattServiceNode,
  GattValueEvent,
  GattValueListener
} from '../main/ets/features/gatt/domain/GattProfile';
import { GattConnectionRegistry } from '../main/ets/features/gatt/data/GattConnectionRegistry';
import { DefaultGattFacade } from '../main/ets/features/gatt/data/DefaultGattFacade';
import { IGattTransport } from '../main/ets/features/gatt/data/IGattTransport';
import { LogEvent, LogEventDomain } from '../main/ets/features/session-log/domain/LogEvent';
import { LogEventType } from '../main/ets/features/session-log/domain/LogEventType';
import { LogEventBus } from '../main/ets/features/session-log/domain/LogEventBus';
import { InMemoryLogStore } from '../main/ets/features/session-log/data/InMemoryLogStore';

const DEVICE_ID: string = '11:22:33:44:55:66';
const SERVICE_UUID: string = '0000180d-0000-1000-8000-00805f9b34fb';
const HEART_UUID: string = '00002a37-0000-1000-8000-00805f9b34fb';
const TEMP_UUID: string = '00002a6e-0000-1000-8000-00805f9b34fb';

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, ms);
  });
}

function bleKey(deviceId: string): string {
  return `ble:${deviceId}`;
}

function characteristic(
  uuid: string,
  canRead: boolean,
  canWrite: boolean,
  canWriteNoResponse: boolean,
  canNotify: boolean,
  canIndicate: boolean
): GattCharacteristicNode {
  const node: GattCharacteristicNode = {
    serviceUuid: SERVICE_UUID,
    characteristicUuid: uuid,
    canRead: canRead,
    canWrite: canWrite,
    canWriteNoResponse: canWriteNoResponse,
    canNotify: canNotify,
    canIndicate: canIndicate
  };
  return node;
}

class IoTransport implements IGattTransport {
  failRead: boolean = false;
  writesStarted: number = 0;
  lastWriteNoResponse: boolean = false;
  notifyEnable: boolean = false;
  notifyIndicate: boolean = false;
  private readonly pending: Array<(ok: boolean) => void> = [];
  private listener: GattValueListener | null = null;

  connect(_deviceId: string): Promise<string[]> {
    const uuids: string[] = [SERVICE_UUID];
    return Promise.resolve(uuids);
  }

  disconnect(_deviceId: string): Promise<void> {
    return Promise.resolve();
  }

  cancelConnect(_deviceId: string): void {
  }

  services(_deviceId: string): GattServiceNode[] {
    const heart: GattCharacteristicNode = characteristic(HEART_UUID, true, true, true, true, false);
    const temp: GattCharacteristicNode = characteristic(TEMP_UUID, false, false, true, false, true);
    const chars: GattCharacteristicNode[] = [heart, temp];
    const node: GattServiceNode = {
      serviceUuid: SERVICE_UUID,
      characteristics: chars
    };
    const profile: GattServiceNode[] = [node];
    return profile;
  }

  readCharacteristicValue(
    _deviceId: string,
    _serviceUuid: string,
    _characteristicUuid: string
  ): Promise<Uint8Array> {
    if (this.failRead) {
      return Promise.reject(new GattOperationError(2901000, 'read forbidden'));
    }
    return Promise.resolve(new Uint8Array([0x00, 0x0a]));
  }

  writeCharacteristicValue(
    _deviceId: string,
    _serviceUuid: string,
    _characteristicUuid: string,
    _value: Uint8Array,
    writeNoResponse: boolean
  ): Promise<void> {
    this.writesStarted++;
    this.lastWriteNoResponse = writeNoResponse;
    return new Promise<void>((resolve: () => void, reject: (err: GattOperationError) => void): void => {
      this.pending.push((ok: boolean): void => {
        if (ok) {
          resolve();
          return;
        }
        reject(new GattOperationError(2901001, 'write forbidden'));
      });
    });
  }

  releaseWrite(ok: boolean): void {
    const next: ((ok: boolean) => void) | undefined = this.pending.shift();
    if (next !== undefined) {
      next(ok);
    }
  }

  setCharacteristicChangeNotification(
    _deviceId: string,
    _serviceUuid: string,
    _characteristicUuid: string,
    enable: boolean,
    indicate: boolean
  ): Promise<void> {
    this.notifyEnable = enable;
    this.notifyIndicate = indicate;
    return Promise.resolve();
  }

  onCharacteristicValue(callback: GattValueListener): void {
    this.listener = callback;
  }

  emit(characteristicUuid: string, value: Uint8Array): void {
    const listener: GattValueListener | null = this.listener;
    if (listener === null) {
      return;
    }
    const event: GattValueEvent = {
      deviceId: DEVICE_ID,
      serviceUuid: SERVICE_UUID,
      characteristicUuid: characteristicUuid,
      value: value
    };
    listener(event);
  }
}

function bindIo(): IoTransport {
  const transport: IoTransport = new IoTransport();
  GattFacade.bindFacade(new DefaultGattFacade(transport));
  return transport;
}

export default function gattReadWriteTest() {
  describe('GattReadWrite', () => {
    beforeEach(() => {
      GattConnectionRegistry.clear();
      LogEventBus.bindStore(new InMemoryLogStore());
      GattFacade.resetFacade();
    });

    it('connectCopiesServiceTreeOntoSession', 0, async (): Promise<void> => {
      bindIo();
      await GattFacade.connect(DEVICE_ID);
      const profile: GattServiceNode[] = GattFacade.profile(DEVICE_ID);
      expect(profile.length).assertEqual(1);
      expect(profile[0].serviceUuid).assertEqual(SERVICE_UUID);
      expect(profile[0].characteristics.length).assertEqual(2);
      expect(profile[0].characteristics[0].characteristicUuid).assertEqual(HEART_UUID);
      const found: BleGattSession | null = GattConnectionRegistry.get(DEVICE_ID);
      expect(found !== null).assertTrue();
      const session: BleGattSession = found as BleGattSession;
      expect(session.services !== undefined).assertTrue();
      expect((session.services as string[])[0]).assertEqual(SERVICE_UUID);
      expect(session.profile !== undefined && (session.profile as GattServiceNode[]).length === 1).assertTrue();
    });

    it('readReturnsCharacteristicBytes', 0, async (): Promise<void> => {
      bindIo();
      await GattFacade.connect(DEVICE_ID);
      const value: Uint8Array = await GattFacade.readCharacteristicValue(DEVICE_ID, SERVICE_UUID, HEART_UUID);
      expect(bytesToHex(value)).assertEqual('00:0A');
    });

    it('readFailureAppendsGattError', 0, async (): Promise<void> => {
      const transport: IoTransport = bindIo();
      transport.failRead = true;
      await GattFacade.connect(DEVICE_ID);
      let failed: boolean = false;
      try {
        await GattFacade.readCharacteristicValue(DEVICE_ID, SERVICE_UUID, HEART_UUID);
      } catch (err) {
        failed = true;
        expect(gattErrorCode(err as Object)).assertEqual(2901000);
      }
      expect(failed).assertTrue();
      const domainBle: LogEventDomain = 'ble';
      const logs: LogEvent[] = LogEventBus.query(bleKey(DEVICE_ID), domainBle);
      let errors: number = 0;
      for (let i = 0; i < logs.length; i++) {
        if (logs[i].type === LogEventType.GATT_ERROR && logs[i].message.indexOf('2901000') >= 0) {
          errors++;
        }
      }
      expect(errors).assertEqual(1);
    });

    it('writesAreSerializedAndPreferResponse', 0, async (): Promise<void> => {
      const transport: IoTransport = bindIo();
      await GattFacade.connect(DEVICE_ID);
      const payload: Uint8Array = hexToBytes('01');
      const first: Promise<void> = GattFacade.writeCharacteristicValue(DEVICE_ID, SERVICE_UUID, HEART_UUID, payload);
      const second: Promise<void> = GattFacade.writeCharacteristicValue(DEVICE_ID, SERVICE_UUID, HEART_UUID, payload);
      await delay(20);
      expect(transport.writesStarted).assertEqual(1);
      expect(transport.lastWriteNoResponse).assertFalse();
      transport.releaseWrite(true);
      await first;
      await delay(20);
      expect(transport.writesStarted).assertEqual(2);
      transport.releaseWrite(true);
      await second;
    });

    it('writeNoResponseWhenWritePropertyMissing', 0, async (): Promise<void> => {
      const transport: IoTransport = bindIo();
      await GattFacade.connect(DEVICE_ID);
      const pending: Promise<void> = GattFacade.writeCharacteristicValue(
        DEVICE_ID,
        SERVICE_UUID,
        TEMP_UUID,
        hexToBytes('FF')
      );
      await delay(20);
      expect(transport.writesStarted).assertEqual(1);
      expect(transport.lastWriteNoResponse).assertTrue();
      transport.releaseWrite(true);
      await pending;
    });

    it('writeFailureLogsAndReleasesQueue', 0, async (): Promise<void> => {
      const transport: IoTransport = bindIo();
      await GattFacade.connect(DEVICE_ID);
      const payload: Uint8Array = hexToBytes('01');
      const first: Promise<void> = GattFacade.writeCharacteristicValue(DEVICE_ID, SERVICE_UUID, HEART_UUID, payload);
      const second: Promise<void> = GattFacade.writeCharacteristicValue(DEVICE_ID, SERVICE_UUID, HEART_UUID, payload);
      await delay(20);
      transport.releaseWrite(false);
      let failed: boolean = false;
      try {
        await first;
      } catch (err) {
        failed = true;
        expect(gattErrorCode(err as Object)).assertEqual(2901001);
      }
      expect(failed).assertTrue();
      await delay(20);
      expect(transport.writesStarted).assertEqual(2);
      transport.releaseWrite(true);
      await second;
      const domainBle: LogEventDomain = 'ble';
      const logs: LogEvent[] = LogEventBus.query(bleKey(DEVICE_ID), domainBle);
      let errors: number = 0;
      for (let i = 0; i < logs.length; i++) {
        if (logs[i].type === LogEventType.GATT_ERROR && logs[i].message.indexOf('2901001') >= 0) {
          errors++;
        }
      }
      expect(errors).assertEqual(1);
    });

    it('notifyAppendsBleLogAndFansOutValue', 0, async (): Promise<void> => {
      const transport: IoTransport = bindIo();
      await GattFacade.connect(DEVICE_ID);
      let seen: string = '';
      const listener: GattValueListener = (event: GattValueEvent): void => {
        seen = bytesToHex(event.value);
      };
      GattFacade.subscribeValues(listener);
      await GattFacade.setCharacteristicChangeNotification(DEVICE_ID, SERVICE_UUID, HEART_UUID, true);
      expect(transport.notifyEnable).assertTrue();
      expect(transport.notifyIndicate).assertFalse();
      transport.emit(HEART_UUID, hexToBytes('00:3C'));
      const domainBle: LogEventDomain = 'ble';
      const logs: LogEvent[] = LogEventBus.query(bleKey(DEVICE_ID), domainBle);
      let notify: LogEvent | null = null;
      for (let i = 0; i < logs.length; i++) {
        if (logs[i].type === LogEventType.GATT_NOTIFY) {
          notify = logs[i];
        }
      }
      expect(notify !== null).assertTrue();
      const event: LogEvent = notify as LogEvent;
      expect(event.domain).assertEqual(domainBle);
      expect(event.deviceKey).assertEqual(bleKey(DEVICE_ID));
      expect(event.message).assertEqual(`${HEART_UUID} 00:3C`);
      expect(seen).assertEqual('00:3C');
      GattFacade.unsubscribeValues(listener);
    });

    it('indicateCharacteristicUsesIndication', 0, async (): Promise<void> => {
      const transport: IoTransport = bindIo();
      await GattFacade.connect(DEVICE_ID);
      await GattFacade.setCharacteristicChangeNotification(DEVICE_ID, SERVICE_UUID, TEMP_UUID, true);
      expect(transport.notifyEnable).assertTrue();
      expect(transport.notifyIndicate).assertTrue();
    });
  });
}
