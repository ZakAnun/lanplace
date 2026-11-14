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
