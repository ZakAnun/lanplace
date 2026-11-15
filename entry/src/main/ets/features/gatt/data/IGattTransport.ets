import { GattServiceNode, GattValueListener } from '../domain/GattProfile';

export const GATT_PROFILE_STATE_DISCONNECTED: number = 0;
export const GATT_PROFILE_STATE_CONNECTED: number = 2;

export interface GattLinkStateEvent {
  deviceId: string;
  state: number;
}

export type GattLinkStateCallback = (state: GattLinkStateEvent) => void;

export type GattHandleValueCallback = (
  serviceUuid: string,
  characteristicUuid: string,
  value: Uint8Array
) => void;

export interface IGattClientHandle {
  connect(): void;
  disconnect(): void;
  close(): void;
  getServices(): Promise<GattServiceNode[]>;
  readCharacteristicValue(serviceUuid: string, characteristicUuid: string): Promise<Uint8Array>;
  writeCharacteristicValue(
    serviceUuid: string,
    characteristicUuid: string,
    value: Uint8Array,
    writeNoResponse: boolean
  ): Promise<void>;
  setCharacteristicChangeNotification(
    serviceUuid: string,
    characteristicUuid: string,
    enable: boolean,
    indicate: boolean
  ): Promise<void>;
  on(type: string, callback: GattLinkStateCallback): void;
  off(type: string, callback: GattLinkStateCallback): void;
  onCharacteristicChange(callback: GattHandleValueCallback): void;
  offCharacteristicChange(callback: GattHandleValueCallback): void;
}

export interface IGattClientFactory {
  create(deviceId: string): IGattClientHandle;
}

export interface IGattTransport {
  connect(deviceId: string): Promise<string[]>;
  disconnect(deviceId: string): Promise<void>;
  cancelConnect(deviceId: string): void;
  services(deviceId: string): GattServiceNode[];
  readCharacteristicValue(deviceId: string, serviceUuid: string, characteristicUuid: string): Promise<Uint8Array>;
  writeCharacteristicValue(
    deviceId: string,
    serviceUuid: string,
    characteristicUuid: string,
    value: Uint8Array,
    writeNoResponse: boolean
  ): Promise<void>;
  setCharacteristicChangeNotification(
    deviceId: string,
    serviceUuid: string,
    characteristicUuid: string,
    enable: boolean,
    indicate: boolean
  ): Promise<void>;
  onCharacteristicValue(callback: GattValueListener): void;
}

export interface GattClock {
  schedule(delayMs: number, onFire: () => void): number;
  cancel(timerId: number): void;
}

export class SystemGattClock implements GattClock {
  schedule(delayMs: number, onFire: () => void): number {
    const timerId: number = setTimeout(onFire, delayMs) as number;
    return timerId;
  }

  cancel(timerId: number): void {
    clearTimeout(timerId);
  }
}
