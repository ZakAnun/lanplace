import { ble } from '@kit.ConnectivityKit';
import { GattOperationError } from '../domain/GattFacade';
import { GattCharacteristicNode, GattServiceNode } from '../domain/GattProfile';
import { GattClientHost } from './GattClientHost';
import {
  GattHandleValueCallback,
  GattLinkStateCallback,
  IGattClientFactory,
  IGattClientHandle
} from './IGattTransport';

class HarmonyGattHandle implements IGattClientHandle {
  private readonly client: ble.GattClientDevice;
  private readonly wrapped: Map<GattLinkStateCallback, (state: ble.BLEConnectionChangeState) => void> = new Map();
  private readonly cached: Map<string, ble.BLECharacteristic> = new Map();
  private valueWrapped: ((characteristic: ble.BLECharacteristic) => void) | null = null;

  constructor(client: ble.GattClientDevice) {
    this.client = client;
  }

  connect(): void {
    this.client.connect();
  }

  disconnect(): void {
    this.client.disconnect();
  }

  close(): void {
    this.client.close();
  }

  getServices(): Promise<GattServiceNode[]> {
    return this.client.getServices().then((services: Array<ble.GattService>): GattServiceNode[] => {
      const nodes: GattServiceNode[] = [];
      for (let i = 0; i < services.length; i++) {
        nodes.push(this.toService(services[i]));
      }
      return nodes;
    });
  }

  readCharacteristicValue(serviceUuid: string, characteristicUuid: string): Promise<Uint8Array> {
    const found: ble.BLECharacteristic | undefined = this.cached.get(this.cacheKey(serviceUuid, characteristicUuid));
    if (found === undefined) {
      return Promise.reject(new GattOperationError(-1, 'unknown characteristic'));
    }
    try {
      return this.client.readCharacteristicValue(found).then((result: ble.BLECharacteristic): Uint8Array => {
        return new Uint8Array(result.characteristicValue);
      });
    } catch (err) {
      return Promise.reject(err);
    }
  }

  writeCharacteristicValue(
    serviceUuid: string,
    characteristicUuid: string,
    value: Uint8Array,
    writeNoResponse: boolean
  ): Promise<void> {
    const found: ble.BLECharacteristic | undefined = this.cached.get(this.cacheKey(serviceUuid, characteristicUuid));
    if (found === undefined) {
      return Promise.reject(new GattOperationError(-1, 'unknown characteristic'));
    }
    found.characteristicValue = this.toBuffer(value);
    const writeType: ble.GattWriteType = writeNoResponse ?
      ble.GattWriteType.WRITE_NO_RESPONSE : ble.GattWriteType.WRITE;
    try {
      return this.client.writeCharacteristicValue(found, writeType);
    } catch (err) {
      return Promise.reject(err);
    }
  }

  setCharacteristicChangeNotification(
    serviceUuid: string,
    characteristicUuid: string,
    enable: boolean,
    indicate: boolean
  ): Promise<void> {
    const found: ble.BLECharacteristic | undefined = this.cached.get(this.cacheKey(serviceUuid, characteristicUuid));
    if (found === undefined) {
      return Promise.reject(new GattOperationError(-1, 'unknown characteristic'));
    }
    try {
      if (indicate) {
        return this.client.setCharacteristicChangeIndication(found, enable);
      }
      return this.client.setCharacteristicChangeNotification(found, enable);
    } catch (err) {
      return Promise.reject(err);
    }
  }

  on(_type: string, callback: GattLinkStateCallback): void {
    const wrapped = (state: ble.BLEConnectionChangeState): void => {
      callback({
        deviceId: state.deviceId,
        state: state.state as number
      });
    };
    this.wrapped.set(callback, wrapped);
    this.client.on('BLEConnectionStateChange', wrapped);
  }

  off(_type: string, callback: GattLinkStateCallback): void {
    const wrapped: ((state: ble.BLEConnectionChangeState) => void) | undefined = this.wrapped.get(callback);
    if (wrapped === undefined) {
      return;
    }
    this.client.off('BLEConnectionStateChange', wrapped);
    this.wrapped.delete(callback);
  }

  onCharacteristicChange(callback: GattHandleValueCallback): void {
    const wrapped = (characteristic: ble.BLECharacteristic): void => {
      callback(
        characteristic.serviceUuid,
        characteristic.characteristicUuid,
        new Uint8Array(characteristic.characteristicValue)
      );
    };
    this.valueWrapped = wrapped;
    try {
      this.client.on('BLECharacteristicChange', wrapped);
    } catch (err) {
      this.valueWrapped = null;
      throw err as Error;
    }
  }

  offCharacteristicChange(_callback: GattHandleValueCallback): void {
    const wrapped: ((characteristic: ble.BLECharacteristic) => void) | null = this.valueWrapped;
    if (wrapped === null) {
      return;
    }
    try {
      this.client.off('BLECharacteristicChange', wrapped);
    } catch (_offErr) {
    }
    this.valueWrapped = null;
  }

  private cacheKey(serviceUuid: string, characteristicUuid: string): string {
    return `${serviceUuid}|${characteristicUuid}`;
  }

  private toBuffer(value: Uint8Array): ArrayBuffer {
    const copy: Uint8Array = new Uint8Array(value.length);
    for (let i = 0; i < value.length; i++) {
      copy[i] = value[i];
    }
    return copy.buffer;
  }

  private toService(service: ble.GattService): GattServiceNode {
    const chars: GattCharacteristicNode[] = [];
    const raw: Array<ble.BLECharacteristic> = service.characteristics;
    for (let i = 0; i < raw.length; i++) {
      const item: ble.BLECharacteristic = raw[i];
      this.cached.set(this.cacheKey(item.serviceUuid, item.characteristicUuid), item);
      chars.push(this.toCharacteristic(item));
    }
    const node: GattServiceNode = {
      serviceUuid: service.serviceUuid,
      characteristics: chars
    };
    return node;
  }

  private toCharacteristic(item: ble.BLECharacteristic): GattCharacteristicNode {
    const props: ble.GattProperties | undefined = item.properties;
    const node: GattCharacteristicNode = {
      serviceUuid: item.serviceUuid,
      characteristicUuid: item.characteristicUuid,
      canRead: props !== undefined && props.read === true,
      canWrite: props !== undefined && props.write === true,
      canWriteNoResponse: props !== undefined && props.writeNoResponse === true,
      canNotify: props !== undefined && props.notify === true,
      canIndicate: props !== undefined && props.indicate === true
    };
    return node;
  }
}

class HarmonyGattFactory implements IGattClientFactory {
  create(deviceId: string): IGattClientHandle {
    return new HarmonyGattHandle(ble.createGattClientDevice(deviceId));
  }
}

export class HarmonyBleGattClient extends GattClientHost {
  constructor() {
    super(new HarmonyGattFactory());
  }
}
