export enum DeviceLinkState {
  Discovered = 0,
  Available = 1,
  Connected = 2
}

export interface ScannedDevice {
  deviceId: string;
  displayName: string;
  rssi: number;
  connectable: boolean;
  detailLine: string;
  advertSummary: string;
  linkState: DeviceLinkState;
  advertLocalName: string;
  advertFlags?: number;
  advertTxPower?: number;
  advertServiceUuids: string[];
  advertManufacturerHex: string;
  advertServiceDataHex: string;
}
