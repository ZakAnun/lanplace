import { describe, it, expect } from '@ohos/hypium';
import { isHuaweiPermissionReason, nextBluetoothPermissionStep } from '../main/ets/common/PermissionPurpose';

export default function permissionPurposeTest() {
  describe('PermissionPurpose', () => {
    it('huaweiReasonRejectsMissingPeriod', 0, () => {
      expect(isHuaweiPermissionReason('用于扫描并展示周围蓝牙设备')).assertFalse();
    });
    it('huaweiReasonRejectsVagueCopy', 0, () => {
      expect(isHuaweiPermissionReason('需要权限')).assertFalse();
      expect(isHuaweiPermissionReason('获取权限。')).assertFalse();
      expect(isHuaweiPermissionReason('使用蓝牙。')).assertFalse();
    });
    it('huaweiReasonAcceptsBluetoothScanPurpose', 0, () => {
      expect(isHuaweiPermissionReason('用于扫描并展示周围蓝牙设备。')).assertTrue();
      expect(isHuaweiPermissionReason('Used to scan and display nearby Bluetooth devices.')).assertTrue();
    });
    it('firstSystemDenyWaitsInsteadOfSettings', 0, () => {
      expect(nextBluetoothPermissionStep(true, true, false)).assertEqual('done');
      expect(nextBluetoothPermissionStep(false, true, false)).assertEqual('wait');
    });
    it('secondTriggerOpensSettingsAfterDeny', 0, () => {
      expect(nextBluetoothPermissionStep(false, false, false)).assertEqual('settings');
      expect(nextBluetoothPermissionStep(false, true, true)).assertEqual('settings');
    });
  });
}
