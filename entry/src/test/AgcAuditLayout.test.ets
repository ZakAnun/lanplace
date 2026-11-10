/**
 * 华为审核相关：横屏附近设备页布局预算（叠字/雷达挤出主流程）。
 * 对应驳回场景「核心功能 UI 异常」的回归断言。
 */
import { describe, it, expect } from '@ohos/hypium';
import {
  LANDSCAPE_RIGHT_RAIL_WIDTH,
  computeLandscapeLeftChromeVp,
  computeRadarCanvasSize,
  isLandscapeLayout,
  radarZoneWidth
} from '../main/ets/common/RadarLayoutHelper';

export default function agcAuditLayoutTest() {
  describe('AgcAuditLayout', () => {
    it('landscapeRightRailWideEnoughForInfoAndActions', 0, () => {
      expect(LANDSCAPE_RIGHT_RAIL_WIDTH).assertEqual(176);
    });

    it('landscapeChromeFitsTypicalPhoneHeight', 0, () => {
      const panelHeight = 360;
      const zoneW = radarZoneWidth(780, true);
      const withPicker = computeRadarCanvasSize(zoneW, panelHeight, true, true);
      const chrome = computeLandscapeLeftChromeVp(true);
      expect(withPicker + chrome <= panelHeight + 2).assertTrue();
      expect(withPicker >= 160).assertTrue();
    });

    it('landscapeChromeIgnoresPicker', 0, () => {
      expect(computeLandscapeLeftChromeVp(false)).assertEqual(16);
      expect(computeLandscapeLeftChromeVp(true)).assertEqual(16);
    });

    it('portraitStillRecognized', 0, () => {
      expect(isLandscapeLayout(400, 800)).assertFalse();
      expect(isLandscapeLayout(800, 400)).assertTrue();
    });

    it('landscapeRadarIgnoresPickerHeight', 0, () => {
      const h = 380;
      const w = radarZoneWidth(700, true);
      const withPicker = computeRadarCanvasSize(w, h, true, true);
      const withoutPicker = computeRadarCanvasSize(w, h, true, false);
      expect(withPicker).assertEqual(withoutPicker);
    });

    it('landscapeZonesDoNotOverlap', 0, () => {
      const panelWidth = 780;
      const zone = radarZoneWidth(panelWidth, true);
      const gap = 12;
      expect(zone + gap + LANDSCAPE_RIGHT_RAIL_WIDTH <= panelWidth + 1).assertTrue();
      expect(zone >= 160).assertTrue();
    });
  });
}
