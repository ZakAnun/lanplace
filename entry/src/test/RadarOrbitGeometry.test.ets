import { describe, it, expect } from '@ohos/hypium';
import {
  canvasLayoutScale,
  clampDeviceOrbitLayout,
  distanceLayout,
  evalQuadraticBezier,
  layoutRadiusToDraw,
  minOrbitRadiusLayoutVp,
  hubEdgeRadiusLayoutVp,
  maxDeviceVisualRadiusLayoutVp,
  orbitPushUnitVector,
  PHASE_DIRECTION_BLEND_FRAC
} from '../main/ets/common/RadarOrbitGeometry';

export default function radarOrbitGeometryTest() {
  describe('RadarOrbitGeometry', () => {
    it('minOrbitLargerThanHubEdge', 0, () => {
      const hubD = 34;
      expect(minOrbitRadiusLayoutVp(hubD, 1) > hubEdgeRadiusLayoutVp(hubD)).assertTrue();
    });

    it('minOrbitGrowsWithCanvasScale', 0, () => {
      const hubD = 34;
      expect(minOrbitRadiusLayoutVp(hubD, 1.5) > minOrbitRadiusLayoutVp(hubD, 1)).assertTrue();
    });

    it('clampLeavesFarPointsUnchanged', 0, () => {
      const minR = minOrbitRadiusLayoutVp(34, 1);
      const p = clampDeviceOrbitLayout(100, 50, 50, 50, minR, 0);
      expect(p.x).assertEqual(100);
      expect(p.y).assertEqual(50);
    });

    it('clampPushesToMinRadius', 0, () => {
      const minR = minOrbitRadiusLayoutVp(34, 1);
      const cx = 140;
      const cy = 140;
      const p = clampDeviceOrbitLayout(cx + 2, cy, cx, cy, minR, 1.2);
      const dist = distanceLayout(p.x, p.y, cx, cy);
      expect(Math.abs(dist - minR) < 0.01).assertTrue();
    });

    it('clampNeverBelowMinRadiusNearBoundary', 0, () => {
      const minR = minOrbitRadiusLayoutVp(34, 1);
      const cx = 80;
      const cy = 80;
      for (let i = 0; i < 20; i++) {
        const distIn = minR - (i / 19) * minR * 0.15;
        const p = clampDeviceOrbitLayout(cx + distIn, cy, cx, cy, minR, 0.7);
        const outDist = distanceLayout(p.x, p.y, cx, cy);
        expect(outDist >= minR - 0.01).assertTrue();
      }
    });

    it('clampZeroDistanceUsesPhase', 0, () => {
      const minR = minOrbitRadiusLayoutVp(34, 1);
      const cx = 0;
      const cy = 0;
      const phase = Math.PI / 4;
      const p = clampDeviceOrbitLayout(cx, cy, cx, cy, minR, phase);
      expect(Math.abs(p.x - minR * Math.cos(phase)) < 0.01).assertTrue();
      expect(Math.abs(p.y - minR * Math.sin(phase)) < 0.01).assertTrue();
    });

    it('orbitPushUsesPhaseWhenNearCenter', 0, () => {
      const minR = minOrbitRadiusLayoutVp(34, 1);
      const phase = Math.PI / 3;
      const dir = orbitPushUnitVector(0.01, 0, 0.01 * 0.01, minR, phase);
      expect(Math.abs(dir.ux - Math.cos(phase)) < 0.05).assertTrue();
      expect(Math.abs(dir.uy - Math.sin(phase)) < 0.05).assertTrue();
    });

    it('evalQuadraticBezierEndpoints', 0, () => {
      const p0 = evalQuadraticBezier(0, 0, 0, 5, 5, 10, 0);
      expect(p0.x).assertEqual(0);
      expect(p0.y).assertEqual(0);
      const p1 = evalQuadraticBezier(1, 0, 0, 5, 5, 10, 0);
      expect(p1.x).assertEqual(10);
      expect(p1.y).assertEqual(0);
    });

    it('layoutRadiusToDrawScales', 0, () => {
      expect(layoutRadiusToDraw(10, 2)).assertEqual(20);
    });

    it('maxVisualRadiusScalesWithCanvas', 0, () => {
      expect(maxDeviceVisualRadiusLayoutVp(1.5) > maxDeviceVisualRadiusLayoutVp(1)).assertTrue();
    });

    it('canvasLayoutScaleZeroReference', 0, () => {
      expect(canvasLayoutScale(280, 0)).assertEqual(1);
    });

    it('orbitPushAtBlendBoundary', 0, () => {
      const minR = minOrbitRadiusLayoutVp(34, 1);
      const dist = minR * PHASE_DIRECTION_BLEND_FRAC;
      const dir = orbitPushUnitVector(dist, 0, dist * dist, minR, Math.PI / 2);
      expect(dir.ux).assertEqual(1);
      expect(Math.abs(dir.uy) < 0.01).assertTrue();
    });

    it('clampManyRandomPointsStayOutsideMinR', 0, () => {
      const minR = minOrbitRadiusLayoutVp(34, 1);
      const cx = 140;
      const cy = 140;
      for (let i = 0; i < 30; i++) {
        const angle = (i / 30) * Math.PI * 2;
        const distIn = (i % 10) * 0.3;
        const sx = cx + Math.cos(angle) * distIn;
        const sy = cy + Math.sin(angle) * distIn;
        const p = clampDeviceOrbitLayout(sx, sy, cx, cy, minR, angle);
        expect(distanceLayout(p.x, p.y, cx, cy) >= minR - 0.02).assertTrue();
      }
    });
  });
}
