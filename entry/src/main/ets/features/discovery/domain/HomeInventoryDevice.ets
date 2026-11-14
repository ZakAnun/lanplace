import { DeviceLinkState } from '../../../shared/ble/ScannedDevice';

export enum InventoryDeviceKind {
  Ble = 0,
  Lan = 1
}

export interface HomeInventoryDevice {
  deviceKey: string;
  kind: InventoryDeviceKind;
  displayName: string;
  detailLine: string;
  extraLine: string;
  rssi: number;
  linkState: DeviceLinkState;
}
