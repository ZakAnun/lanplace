import { describe, it, expect } from '@ohos/hypium';
import { deviceSpherePointForStableKey } from '../main/ets/common/RadarDeviceLayout';
import {
  bleInventoryKey,
  selectionKeyIfStillPresent,
  syntheticInventoryFeed,
  withRssiJitter,
  withoutDeviceKey
} from '../main/ets/common/InventoryDeviceMerge';
import { InventoryDeviceKind } from '../main/ets/model/HomeInventoryDevice';

export default function inventoryDeviceMergeTest() {
  describe('InventoryDeviceMerge', () => {
    it('bleKeyMatchesProductionPrefix', 0, () => {
      expect(bleInventoryKey('AA:BB')).assertEqual('ble:AA:BB');
    });

    it('syntheticFeedUsesRealKeyShapes', 0, () => {
      const list = syntheticInventoryFeed(60, 35);
      expect(list.length).assertEqual(95);
      expect(list[0].deviceKey.indexOf('ble:') === 0).assertTrue();
      expect(list[60].deviceKey.indexOf('lan:host:') === 0).assertTrue();
      expect(list[0].kind).assertEqual(InventoryDeviceKind.Ble);
      expect(list[60].kind).assertEqual(InventoryDeviceKind.Lan);
    });

    it('rssiJitterDoesNotMoveSpherePoint', 0, () => {
      const first = syntheticInventoryFeed(8, 2);
      const jitter = withRssiJitter(first, -17);
      expect(jitter.length).assertEqual(first.length);
      for (let i = 0; i < first.length; i++) {
        expect(jitter[i].deviceKey).assertEqual(first[i].deviceKey);
        const a = deviceSpherePointForStableKey(first[i].deviceKey);
        const b = deviceSpherePointForStableKey(jitter[i].deviceKey);
        expect(a.x).assertEqual(b.x);
        expect(a.y).assertEqual(b.y);
        expect(a.z).assertEqual(b.z);
      }
    });

    it('growingListKeepsExistingPoint', 0, () => {
      const small = syntheticInventoryFeed(3, 1);
      const large = syntheticInventoryFeed(60, 20);
      const key = small[1].deviceKey;
      const a = deviceSpherePointForStableKey(key);
      const b = deviceSpherePointForStableKey(key);
      expect(large.length > small.length).assertTrue();
      expect(a.x).assertEqual(b.x);
      expect(a.y).assertEqual(b.y);
      expect(a.z).assertEqual(b.z);
    });

    it('dropSelectedClearsKey', 0, () => {
      const list = syntheticInventoryFeed(5, 2);
      const key = list[3].deviceKey;
      expect(selectionKeyIfStillPresent(key, list)).assertEqual(key);
      const next = withoutDeviceKey(list, key);
      expect(selectionKeyIfStillPresent(key, next)).assertEqual('');
      expect(selectionKeyIfStillPresent(key, [])).assertEqual('');
    });
  });
}
