import { access } from '@kit.ConnectivityKit';

export class BluetoothHelper {
  static isEnabled(): boolean {
    try {
      return access.getState() === access.BluetoothState.STATE_ON;
    } catch (_err) {
      return true;
    }
  }
}
