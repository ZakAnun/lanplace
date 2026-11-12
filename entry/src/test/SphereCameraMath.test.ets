import { describe, it, expect } from '@ohos/hypium';
import {
  applyOrbitPan,
  clampOrbitPitch,
  clampOrbitSpeed,
  decayOrbitSpeed,
  isTapGesture,
  localToNdc,
  MAX_ORBIT_SPEED_RAD,
  orbitEye,
  pickNearestFrontKey,
  pointFacingAlpha,
  pointFacingScale,
  shouldResumeAutoRotate,
  sphereFacing,
  worldToCanvas,
  PITCH_LIMIT_RAD
} from '../main/ets/common/SphereCameraMath';
import { deviceSpherePointForStableKey, Vec3 } from '../main/ets/common/RadarDeviceLayout';
import { syntheticInventoryFeed } from '../main/ets/common/InventoryDeviceMerge';

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
    it('sphereFacingFrontAndBack', 0, () => {
      const eye: Vec3 = { x: 0, y: 0, z: 3 };
      const front: Vec3 = { x: 0, y: 0, z: 1 };
      const back: Vec3 = { x: 0, y: 0, z: -1 };
      expect(Math.abs(sphereFacing(front, eye) - 1) < 0.001).assertTrue();
      expect(Math.abs(sphereFacing(back, eye) + 1) < 0.001).assertTrue();
    });
    it('pointFacingFrontLargerBrighter', 0, () => {
      expect(pointFacingScale(1) > pointFacingScale(-1)).assertTrue();
      expect(pointFacingAlpha(1) > pointFacingAlpha(-1)).assertTrue();
    });
    it('worldToCanvasFrontCenter', 0, () => {
      const point: Vec3 = { x: 0, y: 0, z: 1 };
      const eye: Vec3 = { x: 0, y: 0, z: 3 };
      const p = worldToCanvas(point, eye, 50 * Math.PI / 180, 100);
      expect(Math.abs(p.x - 50) < 0.5).assertTrue();
      expect(Math.abs(p.y - 50) < 0.5).assertTrue();
      expect(p.z < 0).assertTrue();
    });
    it('worldToCanvasBackPointBehindCamera', 0, () => {
      const point: Vec3 = { x: 0, y: 0, z: 4 };
      const eye: Vec3 = { x: 0, y: 0, z: 3 };
      const p = worldToCanvas(point, eye, 50 * Math.PI / 180, 100);
      expect(p.z > 0).assertTrue();
    });
    it('orbitPanFollowsHand', 0, () => {
      const next = applyOrbitPan(0, 0, 20, 10, 0.01);
      expect(next.x < 0).assertTrue();
      expect(next.y > 0).assertTrue();
    });
    it('orbitSpeedIsCapped', 0, () => {
      expect(clampOrbitSpeed(40)).assertEqual(MAX_ORBIT_SPEED_RAD);
      expect(clampOrbitSpeed(-40)).assertEqual(-MAX_ORBIT_SPEED_RAD);
    });
    it('orbitSpeedDecaysWithTime', 0, () => {
      const later = decayOrbitSpeed(2, 0.55);
      expect(later < 1.0).assertTrue();
      expect(later > 0.5).assertTrue();
    });
    it('pickIgnoresBackHemisphereOnDenseFeed', 0, () => {
      const feed = syntheticInventoryFeed(70, 25);
      const keys: string[] = [];
      for (let i = 0; i < feed.length; i++) {
        keys.push(feed[i].deviceKey);
      }
      const yaw = 0;
      const pitch = 0.18;
      const picked = pickNearestFrontKey(keys, 140, 140, yaw, pitch, 280, 80);
      expect(keys.length).assertEqual(95);
      expect(picked.length > 0).assertTrue();
      const facing = sphereFacing(deviceSpherePointForStableKey(picked), orbitEye(yaw, pitch));
      expect(facing > 0).assertTrue();
    });
  });
}
