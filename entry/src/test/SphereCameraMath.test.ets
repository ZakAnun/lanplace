import { describe, it, expect } from '@ohos/hypium';
import {
  isTapGesture,
  clampOrbitPitch,
  orbitEye,
  shouldResumeAutoRotate,
  localToNdc,
  PITCH_LIMIT_RAD
} from '../main/ets/common/SphereCameraMath';

export default function sphereCameraMathTest() {
  describe('SphereCameraMath', () => {
    it('isTapGestureSlop', 0, () => {
      expect(isTapGesture(3, 4)).assertTrue();
      expect(isTapGesture(8, 0)).assertFalse();
    });
    it('clampOrbitPitch', 0, () => {
      expect(clampOrbitPitch(2)).assertEqual(PITCH_LIMIT_RAD);
      expect(clampOrbitPitch(-2)).assertEqual(-PITCH_LIMIT_RAD);
    });
    it('orbitEyeFront', 0, () => {
      const e = orbitEye(0, 0, 3);
      expect(Math.abs(e.z - 3) < 0.001).assertTrue();
      expect(Math.abs(e.x) < 0.001).assertTrue();
    });
    it('resumeAutoRotate', 0, () => {
      expect(shouldResumeAutoRotate(0.1)).assertTrue();
      expect(shouldResumeAutoRotate(0.2)).assertFalse();
    });
    it('localToNdcTopLeft', 0, () => {
      const n = localToNdc(0, 0, 100, 100);
      expect(Math.abs(n.x + 1) < 0.001).assertTrue();
      expect(Math.abs(n.y - 1) < 0.001).assertTrue();
    });
  });
}
