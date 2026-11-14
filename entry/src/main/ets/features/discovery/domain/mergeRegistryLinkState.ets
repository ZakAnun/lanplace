import { DeviceLinkState } from '../../../shared/ble/ScannedDevice';
import { HomeInventoryDevice, InventoryDeviceKind } from './HomeInventoryDevice';

export function applyConnectedBadge(devices: HomeInventoryDevice[], connectedIds: Set<string>): HomeInventoryDevice[] {
  const next: HomeInventoryDevice[] = [];
  for (let i = 0; i < devices.length; i++) {
    const d: HomeInventoryDevice = devices[i];
    const markConnected: boolean = d.kind === InventoryDeviceKind.Ble && connectedIds.has(d.deviceKey);
    next.push({
      deviceKey: d.deviceKey,
      kind: d.kind,
      displayName: d.displayName,
      detailLine: d.detailLine,
      extraLine: d.extraLine,
      rssi: d.rssi,
      linkState: markConnected ? DeviceLinkState.Connected : d.linkState
    });
  }
  return next;
}
