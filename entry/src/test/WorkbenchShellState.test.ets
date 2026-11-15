import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { InventoryDeviceKind } from '../main/ets/features/discovery/domain/HomeInventoryDevice';
import { GattConnectionRegistry } from '../main/ets/features/gatt/data/GattConnectionRegistry';
import { GattFacade } from '../main/ets/features/gatt/domain/GattFacade';
import { WorkbenchTabId } from '../main/ets/features/workbench/domain/WorkbenchTabPolicy';
import { GattSessionPhase } from '../main/ets/features/gatt/domain/GattSessionPhase';
import {
  WorkbenchShellState,
  applyConnectionPhase,
  applyOpenGattDebug,
  createWorkbenchShellState,
  deriveConnectable,
  gattConnectedForPhase,
  resolveGattConnected,
  resolveInitialTab,
  selectWorkbenchTab
} from '../main/ets/features/workbench/domain/WorkbenchShellState';

export default function workbenchShellStateTest() {
  describe('WorkbenchShellState', () => {
    beforeEach(() => {
      GattConnectionRegistry.clear();
      GattFacade.resetFacade();
    });

    it('resolveGattConnectedFalseWhenNoConnectedSession', 0, () => {
      expect(resolveGattConnected('ble:AA:BB:CC:DD:EE:FF')).assertFalse();
      expect(resolveGattConnected('lan:host:192.168.1.8')).assertFalse();
    });

    it('defaultActiveTabIsOverview', 0, () => {
      const state: WorkbenchShellState = createWorkbenchShellState('ble:1', InventoryDeviceKind.Ble, 'Sensor');
      expect(state.activeTab).assertEqual(WorkbenchTabId.Overview);
      expect(state.gattConnected).assertFalse();
      expect(state.linkLost).assertFalse();
      expect(state.deviceKey).assertEqual('ble:1');
      expect(state.kind).assertEqual(InventoryDeviceKind.Ble);
      expect(state.displayName).assertEqual('Sensor');
    });

    it('deriveConnectableBleTrueLanFalse', 0, () => {
      expect(deriveConnectable(InventoryDeviceKind.Ble)).assertTrue();
      expect(deriveConnectable(InventoryDeviceKind.Lan)).assertFalse();
    });

    it('createStateDerivesConnectableFromKind', 0, () => {
      const ble: WorkbenchShellState = createWorkbenchShellState('ble:1', InventoryDeviceKind.Ble, 'Band');
      expect(ble.connectable).assertTrue();
      const lan: WorkbenchShellState = createWorkbenchShellState('lan:host:1', InventoryDeviceKind.Lan, 'Hub');
      expect(lan.connectable).assertFalse();
    });

    it('honorsInitialTabWhenVisible', 0, () => {
      expect(resolveInitialTab(InventoryDeviceKind.Ble, false, WorkbenchTabId.Advert))
        .assertEqual(WorkbenchTabId.Advert);
      expect(resolveInitialTab(InventoryDeviceKind.Lan, false, WorkbenchTabId.Lan))
        .assertEqual(WorkbenchTabId.Lan);
    });

    it('fallsBackToOverviewWhenInitialTabHidden', 0, () => {
      expect(resolveInitialTab(InventoryDeviceKind.Ble, false, WorkbenchTabId.Gatt))
        .assertEqual(WorkbenchTabId.Overview);
      expect(resolveInitialTab(InventoryDeviceKind.Lan, false, WorkbenchTabId.Advert))
        .assertEqual(WorkbenchTabId.Overview);
    });

    it('fallsBackToOverviewWhenInitialTabOmitted', 0, () => {
      expect(resolveInitialTab(InventoryDeviceKind.Ble, false))
        .assertEqual(WorkbenchTabId.Overview);
    });

    it('openGattDebugOnlyWhenConnected', 0, () => {
      expect(applyOpenGattDebug(false, WorkbenchTabId.Overview))
        .assertEqual(WorkbenchTabId.Overview);
      expect(applyOpenGattDebug(true, WorkbenchTabId.Overview))
        .assertEqual(WorkbenchTabId.Gatt);
    });

    it('selectTabDoesNotChangeConnection', 0, () => {
      const state: WorkbenchShellState = createWorkbenchShellState('ble:1', InventoryDeviceKind.Ble, 'Sensor');
      const next: WorkbenchShellState = selectWorkbenchTab(state, WorkbenchTabId.Advert);
      expect(next.activeTab).assertEqual(WorkbenchTabId.Advert);
      expect(next.gattConnected).assertEqual(state.gattConnected);
      expect(next.gattConnected).assertFalse();
    });

    it('selectTabIgnoresHiddenGattWhenDisconnected', 0, () => {
      const state: WorkbenchShellState = createWorkbenchShellState('ble:1', InventoryDeviceKind.Ble, 'Sensor');
      const next: WorkbenchShellState = selectWorkbenchTab(state, WorkbenchTabId.Gatt);
      expect(next.activeTab).assertEqual(WorkbenchTabId.Overview);
    });

    it('lostPhaseClearsGattConnectedAndLeavesOverview', 0, () => {
      expect(gattConnectedForPhase('Lost')).assertFalse();
      expect(gattConnectedForPhase('Connected')).assertTrue();
      expect(gattConnectedForPhase('Disconnected')).assertFalse();
      expect(gattConnectedForPhase(null)).assertFalse();
      const state: WorkbenchShellState = createWorkbenchShellState('ble:1', InventoryDeviceKind.Ble, 'Sensor');
      const onGatt: WorkbenchShellState = {
        deviceKey: state.deviceKey,
        kind: state.kind,
        displayName: state.displayName,
        connectable: state.connectable,
        gattConnected: true,
        linkLost: false,
        activeTab: WorkbenchTabId.Gatt
      };
      const lost: GattSessionPhase = 'Lost';
      const next: WorkbenchShellState = applyConnectionPhase(onGatt, lost);
      expect(next.gattConnected).assertFalse();
      expect(next.linkLost).assertTrue();
      expect(next.activeTab).assertEqual(WorkbenchTabId.Overview);
      const advert: WorkbenchShellState = selectWorkbenchTab(state, WorkbenchTabId.Advert);
      const lostAdvert: WorkbenchShellState = applyConnectionPhase(advert, lost);
      expect(lostAdvert.activeTab).assertEqual(WorkbenchTabId.Advert);
      expect(lostAdvert.gattConnected).assertFalse();
      const disconnected: GattSessionPhase = 'Disconnected';
      const dropped: WorkbenchShellState = applyConnectionPhase(onGatt, disconnected);
      expect(dropped.gattConnected).assertFalse();
      expect(dropped.linkLost).assertFalse();
      expect(dropped.activeTab).assertEqual(WorkbenchTabId.Overview);
      const connected: GattSessionPhase = 'Connected';
      const back: WorkbenchShellState = applyConnectionPhase(next, connected);
      expect(back.gattConnected).assertTrue();
      expect(back.linkLost).assertFalse();
      expect(back.activeTab).assertEqual(WorkbenchTabId.Overview);
    });
  });
}
