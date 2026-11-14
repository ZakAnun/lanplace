export const GATT_CONNECT_TIMEOUT_MS: number = 30000;
export const GATT_ERROR_MAX_CONNECTIONS: number = 2900006;
export const GATT_ERROR_TIMEOUT: number = -100;
export const GATT_TOAST_MAX_CONNECTIONS: string = 'toast_gatt_max_connections';
export const GATT_TOAST_CONNECT_FAILED: string = 'toast_action_failed';

export class GattOperationError extends Error {
  readonly kind: string = 'GattOperationError';
  code: number = 0;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

export function gattFailureResource(code: number): string {
  if (code === GATT_ERROR_MAX_CONNECTIONS) {
    return GATT_TOAST_MAX_CONNECTIONS;
  }
  return GATT_TOAST_CONNECT_FAILED;
}

export function gattErrorCode(err: Object): number {
  const tagged: GattOperationError = err as GattOperationError;
  if (tagged.kind === 'GattOperationError') {
    return tagged.code;
  }
  return -1;
}

export function asGattOperationError(err: Object): GattOperationError {
  const tagged: GattOperationError = err as GattOperationError;
  if (tagged.kind === 'GattOperationError') {
    return tagged;
  }
  return new GattOperationError(-1, 'connect failed');
}

export interface GattFacadeApi {
  connect(deviceId: string): Promise<void>;
  disconnect(deviceId: string): Promise<void>;
  isConnected(deviceId: string): boolean;
}

export class GattFacade {
  private static impl: GattFacadeApi | null = null;

  static bindFacade(impl: GattFacadeApi): void {
    GattFacade.impl = impl;
  }

  static resetFacade(): void {
    GattFacade.impl = null;
  }

  static connect(deviceId: string): Promise<void> {
    const impl: GattFacadeApi | null = GattFacade.impl;
    if (impl === null) {
      return Promise.reject(new GattOperationError(-1, 'unbound'));
    }
    return impl.connect(deviceId);
  }

  static disconnect(deviceId: string): Promise<void> {
    const impl: GattFacadeApi | null = GattFacade.impl;
    if (impl === null) {
      return Promise.reject(new GattOperationError(-1, 'unbound'));
    }
    return impl.disconnect(deviceId);
  }

  static isConnected(deviceId: string): boolean {
    const impl: GattFacadeApi | null = GattFacade.impl;
    if (impl === null) {
      return false;
    }
    return impl.isConnected(deviceId);
  }
}
