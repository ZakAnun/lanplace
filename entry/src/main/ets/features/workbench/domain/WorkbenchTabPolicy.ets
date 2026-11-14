import { InventoryDeviceKind } from '../../discovery/domain/HomeInventoryDevice';

export enum WorkbenchTabId {
  Overview = 0,
  Advert = 1,
  Gatt = 2,
  Lan = 3,
  Log = 4
}

export function visibleTabs(kind: InventoryDeviceKind, gattConnected: boolean): WorkbenchTabId[] {
  if (kind === InventoryDeviceKind.Lan) {
    return [WorkbenchTabId.Overview, WorkbenchTabId.Lan, WorkbenchTabId.Log];
  }
  if (gattConnected) {
    return [
      WorkbenchTabId.Overview,
      WorkbenchTabId.Advert,
      WorkbenchTabId.Gatt,
      WorkbenchTabId.Log
    ];
  }
  return [WorkbenchTabId.Overview, WorkbenchTabId.Advert, WorkbenchTabId.Log];
}
