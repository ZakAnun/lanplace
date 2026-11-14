import { ble } from '@kit.ConnectivityKit';
import { GattClientHost } from './GattClientHost';
import { GattLinkStateCallback, IGattClientFactory, IGattClientHandle } from './IGattTransport';

class HarmonyGattHandle implements IGattClientHandle {
  private readonly client: ble.GattClientDevice;
  private readonly wrapped: Map<GattLinkStateCallback, (state: ble.BLEConnectionChangeState) => void> = new Map();

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

  getServices(): Promise<string[]> {
    return this.client.getServices().then((services: Array<ble.GattService>): string[] => {
      const uuids: string[] = [];
      for (let i = 0; i < services.length; i++) {
        uuids.push(services[i].serviceUuid);
      }
      return uuids;
    });
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
