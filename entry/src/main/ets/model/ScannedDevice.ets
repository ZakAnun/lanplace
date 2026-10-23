export interface ScannedDevice {
  deviceId: string;
  displayName: string;
  rssi: number;
  connectable: boolean;
  detailLine: string;
  advertSummary: string;
}
