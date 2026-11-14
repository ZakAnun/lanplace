import { parseBleDeviceId } from '../../discovery/domain/DeviceWorkbenchParams';
import { InventoryDeviceKind } from '../../discovery/domain/HomeInventoryDevice';
import { GattFacade } from '../../gatt/domain/GattFacade';
import { WorkbenchTabId, visibleTabs } from './WorkbenchTabPolicy';

export interface WorkbenchShellState {
  deviceKey: string;
  kind: InventoryDeviceKind;
  displayName: string;
  connectable: boolean;
  gattConnected: boolean;
  activeTab: WorkbenchTabId;
}

export function resolveGattConnected(deviceKey: string): boolean {
  const deviceId: string | undefined = parseBleDeviceId(deviceKey);
  if (deviceId === undefined) {
    return false;
  }
  return GattFacade.isConnected(deviceId);
}

export function deriveConnectable(kind: InventoryDeviceKind): boolean {
  return kind === InventoryDeviceKind.Ble;
}

export function resolveInitialTab(
  kind: InventoryDeviceKind,
  gattConnected: boolean,
  initialTab?: WorkbenchTabId
): WorkbenchTabId {
  if (initialTab === undefined) {
    return WorkbenchTabId.Overview;
  }
  const tabs: WorkbenchTabId[] = visibleTabs(kind, gattConnected);
  if (tabs.indexOf(initialTab) >= 0) {
    return initialTab;
  }
  return WorkbenchTabId.Overview;
}

export function applyOpenGattDebug(gattConnected: boolean, activeTab: WorkbenchTabId): WorkbenchTabId {
  if (!gattConnected) {
    return activeTab;
  }
  return WorkbenchTabId.Gatt;
}

export function selectWorkbenchTab(state: WorkbenchShellState, tab: WorkbenchTabId): WorkbenchShellState {
  const tabs: WorkbenchTabId[] = visibleTabs(state.kind, state.gattConnected);
  const nextTab: WorkbenchTabId = tabs.indexOf(tab) >= 0 ? tab : state.activeTab;
  const next: WorkbenchShellState = {
    deviceKey: state.deviceKey,
    kind: state.kind,
    displayName: state.displayName,
    connectable: state.connectable,
    gattConnected: state.gattConnected,
    activeTab: nextTab
  };
  return next;
}

export function createWorkbenchShellState(
  deviceKey: string,
  kind: InventoryDeviceKind,
  displayName: string,
  connectable?: boolean,
  initialTab?: WorkbenchTabId
): WorkbenchShellState {
  const gattConnected: boolean = resolveGattConnected(deviceKey);
  const resolvedConnectable: boolean = connectable !== undefined ? connectable : deriveConnectable(kind);
  const state: WorkbenchShellState = {
    deviceKey: deviceKey,
    kind: kind,
    displayName: displayName,
    connectable: resolvedConnectable,
    gattConnected: gattConnected,
    activeTab: resolveInitialTab(kind, gattConnected, initialTab)
  };
  return state;
}
