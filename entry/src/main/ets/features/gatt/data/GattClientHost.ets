import { GATT_ERROR_TIMEOUT, GattOperationError } from '../domain/GattFacade';
import { BleGattSession } from '../domain/BleGattSession';
import { GattConnectionRegistry } from './GattConnectionRegistry';
import {
  GATT_PROFILE_STATE_CONNECTED,
  GATT_PROFILE_STATE_DISCONNECTED,
  GattLinkStateEvent,
  IGattClientFactory,
  IGattClientHandle,
  IGattTransport
} from './IGattTransport';

class ConnectWaiter {
  settled: boolean = false;
  private readonly onOk: (uuids: string[]) => void;
  private readonly onErr: (err: GattOperationError) => void;

  constructor(onOk: (uuids: string[]) => void, onErr: (err: GattOperationError) => void) {
    this.onOk = onOk;
    this.onErr = onErr;
  }

  resolve(uuids: string[]): void {
    if (this.settled) {
      return;
    }
    this.settled = true;
    this.onOk(uuids);
  }

  reject(err: GattOperationError): void {
    if (this.settled) {
      return;
    }
    this.settled = true;
    this.onErr(err);
  }
}

export class GattClientHost implements IGattTransport {
  private readonly factory: IGattClientFactory;
  private readonly clients: Map<string, IGattClientHandle> = new Map();
  private readonly waiters: Map<string, ConnectWaiter> = new Map();
  private readonly onConnectionStateChange = (state: GattLinkStateEvent): void => {
    this.handleConnectionState(state);
  };

  constructor(factory: IGattClientFactory) {
    this.factory = factory;
  }

  connect(deviceId: string): Promise<string[]> {
    return new Promise<string[]>((resolve: (uuids: string[]) => void, reject: (err: GattOperationError) => void): void => {
      const previous: ConnectWaiter | undefined = this.waiters.get(deviceId);
      if (previous !== undefined) {
        previous.reject(new GattOperationError(-1, 'replaced'));
        this.waiters.delete(deviceId);
      }
      this.dropClient(deviceId);
      const waiter: ConnectWaiter = new ConnectWaiter(resolve, reject);
      this.waiters.set(deviceId, waiter);
      let client: IGattClientHandle;
      try {
        client = this.factory.create(deviceId);
      } catch (err) {
        this.waiters.delete(deviceId);
        reject(this.asGattError(err as Object));
        return;
      }
      this.clients.set(deviceId, client);
      try {
        client.on('BLEConnectionStateChange', this.onConnectionStateChange);
        client.connect();
      } catch (err) {
        this.waiters.delete(deviceId);
        this.dropClient(deviceId);
        reject(this.asGattError(err as Object));
      }
    });
  }

  disconnect(deviceId: string): Promise<void> {
    const client: IGattClientHandle | undefined = this.clients.get(deviceId);
    if (client === undefined) {
      return Promise.resolve();
    }
    try {
      client.off('BLEConnectionStateChange', this.onConnectionStateChange);
    } catch (_offErr) {
    }
    try {
      client.disconnect();
    } catch (err) {
      return Promise.reject(this.asGattError(err as Object));
    }
    try {
      client.close();
    } catch (_closeErr) {
    }
    this.clients.delete(deviceId);
    const waiter: ConnectWaiter | undefined = this.waiters.get(deviceId);
    if (waiter !== undefined) {
      waiter.reject(new GattOperationError(-1, 'disconnected'));
      this.waiters.delete(deviceId);
    }
    return Promise.resolve();
  }

  cancelConnect(deviceId: string): void {
    const waiter: ConnectWaiter | undefined = this.waiters.get(deviceId);
    this.dropClient(deviceId);
    if (waiter !== undefined) {
      waiter.reject(new GattOperationError(GATT_ERROR_TIMEOUT, 'connect timeout'));
      this.waiters.delete(deviceId);
    }
  }

  private handleConnectionState(state: GattLinkStateEvent): void {
    const waiter: ConnectWaiter | undefined = this.waiters.get(state.deviceId);
    if (waiter === undefined || waiter.settled) {
      if (state.state === GATT_PROFILE_STATE_DISCONNECTED) {
        this.markLostIfConnected(state.deviceId);
      }
      return;
    }
    if (state.state === GATT_PROFILE_STATE_CONNECTED) {
      const client: IGattClientHandle | undefined = this.clients.get(state.deviceId);
      if (client === undefined) {
        waiter.reject(new GattOperationError(-1, 'missing client'));
        this.waiters.delete(state.deviceId);
        this.dropClient(state.deviceId);
        return;
      }
      client.getServices().then((uuids: string[]): void => {
        waiter.resolve(uuids);
        this.waiters.delete(state.deviceId);
      }).catch((err: Object): void => {
        waiter.reject(this.asGattError(err));
        this.waiters.delete(state.deviceId);
        this.dropClient(state.deviceId);
      });
      return;
    }
    if (state.state === GATT_PROFILE_STATE_DISCONNECTED) {
      waiter.reject(new GattOperationError(-1, 'disconnected'));
      this.waiters.delete(state.deviceId);
      this.dropClient(state.deviceId);
    }
  }

  private markLostIfConnected(deviceId: string): void {
    const found: BleGattSession | null = GattConnectionRegistry.get(deviceId);
    if (found !== null && found.phase === 'Connected') {
      GattConnectionRegistry.setPhase(deviceId, 'Lost');
    }
  }

  private dropClient(deviceId: string): void {
    const client: IGattClientHandle | undefined = this.clients.get(deviceId);
    if (client === undefined) {
      return;
    }
    try {
      client.off('BLEConnectionStateChange', this.onConnectionStateChange);
    } catch (_offErr) {
    }
    try {
      client.disconnect();
    } catch (_disconnectErr) {
    }
    try {
      client.close();
    } catch (_closeErr) {
    }
    this.clients.delete(deviceId);
  }

  private asGattError(err: Object): GattOperationError {
    const tagged: GattOperationError = err as GattOperationError;
    if (tagged.kind === 'GattOperationError') {
      return tagged;
    }
    const coded: GattOperationError = err as GattOperationError;
    if (typeof coded.code === 'number') {
      const message: string = typeof coded.message === 'string' ? coded.message : '';
      return new GattOperationError(coded.code, message);
    }
    return new GattOperationError(-1, 'gatt failed');
  }
}
