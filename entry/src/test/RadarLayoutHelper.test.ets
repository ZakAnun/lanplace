import { describe, it, expect } from '@ohos/hypium';
import {
  computeRadarCanvasSize,
  isLandscapeLayout,
  LANDSCAPE_RIGHT_RAIL_WIDTH,
  radarZoneWidth
} from '../main/ets/common/RadarLayoutHelper';

export default function radarLayoutHelperTest() {
  describe('RadarLayoutHelper', () => {
    it('isLandscapeLayout', 0, () => {
      expect(isLandscapeLayout(800, 400)).assertTrue();
      expect(isLandscapeLayout(400, 800)).assertFalse();
      expect(isLandscapeLayout(400, 400)).assertFalse();
    });

    it('radarZoneWidthPortrait', 0, () => {
      expect(radarZoneWidth(360, false)).assertEqual(360);
    });

    it('radarZoneWidthLandscape', 0, () => {
      const zone = radarZoneWidth(800, true);
      expect(zone).assertEqual(800 - LANDSCAPE_RIGHT_RAIL_WIDTH - 12);
    });

    it('computeRadarCanvasSizeClamps', 0, () => {
      const size = computeRadarCanvasSize(500, 900, false);
      expect(size >= 200).assertTrue();
      expect(size <= 420).assertTrue();
    });
  });
}
