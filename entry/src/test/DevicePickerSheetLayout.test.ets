import { describe, it, expect } from '@ohos/hypium';
import {
  computeDevicePickerListMaxHeightVp,
  computeDevicePickerScrollHeightVp,
  devicePickerSheetChromeHeightVp,
  PICKER_LIST_MAX_CAP_VP
} from '../main/ets/common/DevicePickerSheetLayout';

export default function devicePickerSheetLayoutTest() {
  describe('DevicePickerSheetLayout', () => {
    it('chromeHeightPositive', 0, () => {
      expect(devicePickerSheetChromeHeightVp() > 0).assertTrue();
    });

    it('listMaxHeightUsesWindowNotPanel', 0, () => {
      const tallWindow = 800;
      const shortWindow = 360;
      expect(computeDevicePickerListMaxHeightVp(tallWindow)).assertEqual(PICKER_LIST_MAX_CAP_VP);
      expect(computeDevicePickerListMaxHeightVp(shortWindow) < PICKER_LIST_MAX_CAP_VP).assertTrue();
    });

    it('scrollHeightCapsAtMax', 0, () => {
      const maxH = 200;
      expect(computeDevicePickerScrollHeightVp(20, maxH)).assertEqual(maxH);
    });

    it('scrollHeightFitsFewDevices', 0, () => {
      const maxH = 360;
      const h = computeDevicePickerScrollHeightVp(2, maxH);
      expect(h < maxH).assertTrue();
      expect(h > 0).assertTrue();
    });
  });
}
