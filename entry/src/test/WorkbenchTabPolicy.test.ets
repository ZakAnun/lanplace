import { describe, it, expect } from '@ohos/hypium';
import { InventoryDeviceKind } from '../main/ets/features/discovery/domain/HomeInventoryDevice';
import { WorkbenchTabId, visibleTabs } from '../main/ets/features/workbench/domain/WorkbenchTabPolicy';

export default function workbenchTabPolicyTest() {
  describe('WorkbenchTabPolicy', () => {
    it('lanDeviceThreeTabs', 0, () => {
      const tabs = visibleTabs(InventoryDeviceKind.Lan, false);
      expect(tabs.length).assertEqual(3);
      expect(tabs[0]).assertEqual(WorkbenchTabId.Overview);
      expect(tabs[1]).assertEqual(WorkbenchTabId.Lan);
      expect(tabs[2]).assertEqual(WorkbenchTabId.Log);
    });

    it('bleDisconnectedNoGatt', 0, () => {
      const tabs = visibleTabs(InventoryDeviceKind.Ble, false);
      expect(tabs.indexOf(WorkbenchTabId.Gatt)).assertEqual(-1);
    });

    it('bleConnectedIncludesGatt', 0, () => {
      const tabs = visibleTabs(InventoryDeviceKind.Ble, true);
      expect(tabs.indexOf(WorkbenchTabId.Gatt) > 0).assertTrue();
    });
  });
}
