import { describe, it, expect } from '@ohos/hypium';
import {
  deviceSpherePointForIndex,
  deviceSpherePointForStableKey,
  goldenSpherePoint
} from '../main/ets/common/RadarDeviceLayout';

export default function radarDeviceLayoutTest() {
  describe('RadarDeviceLayout', () => {
    it('deviceSpherePointForIndexOnUnitSphere', 0, () => {
      const total = 5;
      for (let i = 0; i < total; i++) {
        const p = deviceSpherePointForIndex(i, total);
        const len = Math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
        expect(Math.abs(len - 0.85) < 0.001).assertTrue();
      }
    });

    it('goldenSpherePointOnGivenRadius', 0, () => {
      const total = 8;
      for (let i = 0; i < total; i++) {
        const p = goldenSpherePoint(i, total, 1);
        const len = Math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
        expect(Math.abs(len - 1) < 0.001).assertTrue();
      }
    });

    it('deviceSpherePointForIndexEmpty', 0, () => {
      const p = deviceSpherePointForIndex(0, 0);
      expect(p.x).assertEqual(0);
      expect(p.y).assertEqual(0);
      expect(p.z).assertEqual(0);
    });

    it('deviceSpherePointForStableKeyOnSphere', 0, () => {
      const p = deviceSpherePointForStableKey('ble:aa');
      const len = Math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
      expect(Math.abs(len - 1) < 0.001).assertTrue();
    });

    it('deviceSpherePointForStableKeyStable', 0, () => {
      const a = deviceSpherePointForStableKey('ble:aa');
      const b = deviceSpherePointForStableKey('ble:aa');
      expect(a.x).assertEqual(b.x);
      expect(a.y).assertEqual(b.y);
      expect(a.z).assertEqual(b.z);
    });
  });
}
