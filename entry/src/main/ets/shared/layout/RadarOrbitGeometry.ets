/** Hub 外缘相对直径的 padding（layout vp） */
export const HUB_EDGE_PAD_VP: number = 2;
/** 光点外缘与 hub 外缘最小间隙（layout vp，基准画布） */
export const ORBIT_SKIM_GAP_VP: number = 8;
/** 未选中光点核心半径（layout vp，基准画布） */
export const DEVICE_CORE_VP: number = 6;
/** 选中光点核心半径（layout vp，基准画布） */
export const DEVICE_CORE_SELECTED_VP: number = 7.5;
/** 光晕半径增量（layout vp，基准画布） */
export const DEVICE_HALO_VP: number = 4;
/** 选中外环半径增量（layout vp，基准画布） */
export const DEVICE_SELECTED_RING_VP: number = 9;
/** dist/minR 低于此值时方向向 phase 混合，避免环上半圈甩动 */
export const PHASE_DIRECTION_BLEND_FRAC: number = 0.45;

export interface Point2 {
  x: number;
  y: number;
}

export interface UnitVector {
  ux: number;
  uy: number;
}

export function hubEdgeRadiusLayoutVp(hubDiameterLayoutVp: number): number {
  return hubDiameterLayoutVp / 2 + HUB_EDGE_PAD_VP;
}

export function canvasLayoutScale(canvasSizeLayoutVp: number, referenceCanvasVp: number): number {
  if (referenceCanvasVp <= 0) {
    return 1;
  }
  return canvasSizeLayoutVp / referenceCanvasVp;
}

/** 设备光点最大可视外缘（含选中环），layout vp */
export function maxDeviceVisualRadiusLayoutVp(canvasLayoutScaleFactor: number): number {
  const scale = Math.max(canvasLayoutScaleFactor, 0.01);
  return (DEVICE_CORE_SELECTED_VP + DEVICE_HALO_VP + DEVICE_SELECTED_RING_VP) * scale;
}

export function minOrbitRadiusLayoutVp(hubDiameterLayoutVp: number,
  canvasLayoutScaleFactor: number = 1): number {
  const scale = Math.max(canvasLayoutScaleFactor, 0.01);
  const hubEdge = hubEdgeRadiusLayoutVp(hubDiameterLayoutVp);
  const skim = ORBIT_SKIM_GAP_VP * scale;
  const visualR = maxDeviceVisualRadiusLayoutVp(scale);
  return hubEdge + visualR + skim;
}

export function layoutRadiusToDraw(radiusLayoutVp: number, layoutToDrawScale: number): number {
  return radiusLayoutVp * layoutToDrawScale;
}

function smoothStep01(t: number): number {
  const x = Math.max(0, Math.min(1, t));
  return x * x * (3 - 2 * x);
}

/** 推出方向：近中心时向 phase 混合，保证连续且可预期 */
export function orbitPushUnitVector(
  dx: number,
  dy: number,
  distSq: number,
  minOrbitLayoutVp: number,
  phaseAngleRad: number
): UnitVector {
  const phaseUx = Math.cos(phaseAngleRad);
  const phaseUy = Math.sin(phaseAngleRad);
  if (distSq < 1e-4) {
    return { ux: phaseUx, uy: phaseUy };
  }
  const dist = Math.sqrt(distSq);
  let ux = dx / dist;
  let uy = dy / dist;
  const ratio = dist / Math.max(minOrbitLayoutVp, 1e-3);
  if (ratio < PHASE_DIRECTION_BLEND_FRAC) {
    const blend = smoothStep01(1 - ratio / PHASE_DIRECTION_BLEND_FRAC);
    ux = ux * (1 - blend) + phaseUx * blend;
    uy = uy * (1 - blend) + phaseUy * blend;
    const len = Math.sqrt(ux * ux + uy * uy);
    if (len > 1e-6) {
      ux = ux / len;
      uy = uy / len;
    } else {
      ux = phaseUx;
      uy = phaseUy;
    }
  }
  return { ux: ux, uy: uy };
}

export function distanceLayout(x: number, y: number, cx: number, cy: number): number {
  const dx = x - cx;
  const dy = y - cy;
  return Math.sqrt(dx * dx + dy * dy);
}

export function clampDeviceOrbitLayout(
  sxLayout: number,
  syLayout: number,
  cxLayout: number,
  cyLayout: number,
  minOrbitLayoutVp: number,
  phaseAngleRad: number
): Point2 {
  const dx = sxLayout - cxLayout;
  const dy = syLayout - cyLayout;
  const distSq = dx * dx + dy * dy;
  const minR = minOrbitLayoutVp;
  const minRSq = minR * minR;

  if (distSq >= minRSq) {
    return { x: sxLayout, y: syLayout };
  }

  const dir = orbitPushUnitVector(dx, dy, distSq, minR, phaseAngleRad);
  return {
    x: cxLayout + dir.ux * minR,
    y: cyLayout + dir.uy * minR
  };
}

export function evalQuadraticBezier(t: number, x0: number, y0: number, cx: number, cy: number,
  x1: number, y1: number): Point2 {
  const u = 1 - t;
  const uu = u * u;
  const tt = t * t;
  return {
    x: uu * x0 + 2 * u * t * cx + tt * x1,
    y: uu * y0 + 2 * u * t * cy + tt * y1
  };
}
