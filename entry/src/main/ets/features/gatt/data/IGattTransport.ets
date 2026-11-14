export const GATT_PROFILE_STATE_DISCONNECTED: number = 0;
export const GATT_PROFILE_STATE_CONNECTED: number = 2;

export interface GattLinkStateEvent {
  deviceId: string;
  state: number;
}

export type GattLinkStateCallback = (state: GattLinkStateEvent) => void;

export interface IGattClientHandle {
  connect(): void;
  disconnect(): void;
  close(): void;
  getServices(): Promise<string[]>;
  on(type: string, callback: GattLinkStateCallback): void;
  off(type: string, callback: GattLinkStateCallback): void;
}

export interface IGattClientFactory {
  create(deviceId: string): IGattClientHandle;
}

export interface IGattTransport {
  connect(deviceId: string): Promise<string[]>;
  disconnect(deviceId: string): Promise<void>;
  cancelConnect(deviceId: string): void;
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
