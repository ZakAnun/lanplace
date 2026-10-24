export enum DeviceLinkState {
  Discovered = 0,
  Available = 1
}

export interface ScannedDevice {
  deviceId: string;
  displayName: string;
  rssi: number;
  connectable: boolean;
  detailLine: string;
  advertSummary: string;
  linkState: DeviceLinkState;
}
