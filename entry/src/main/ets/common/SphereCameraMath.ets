import { deviceSpherePointForStableKey, Vec3 } from './RadarDeviceLayout';

export const TAP_SLOP_VP: number = 8;
export const PITCH_LIMIT_RAD: number = 89 * Math.PI / 180;
export const AUTO_ROTATE_RESUME_SPEED: number = 0.15;
export const ORBIT_RADIUS: number = 3;
export const AUTO_ROTATE_YAW_SPEED: number = 0.18;
export const CAMERA_FOV_RAD: number = 50 * Math.PI / 180;
export const MAX_ORBIT_SPEED_RAD: number = 4;
export const ORBIT_COAST_TAU_S: number = 0.55;
export const DEFAULT_ORBIT_CANVAS: number = 280;

export function isTapGesture(dxVp: number, dyVp: number): boolean {
  return dxVp * dxVp + dyVp * dyVp < TAP_SLOP_VP * TAP_SLOP_VP;
}

export function clampOrbitPitch(pitchRad: number): number {
  if (pitchRad > PITCH_LIMIT_RAD) {
    return PITCH_LIMIT_RAD;
  }
  if (pitchRad < -PITCH_LIMIT_RAD) {
    return -PITCH_LIMIT_RAD;
  }
  return pitchRad;
}

export function orbitEye(yawRad: number, pitchRad: number, radius: number = ORBIT_RADIUS): Vec3 {
  const p = clampOrbitPitch(pitchRad);
  const cy = Math.cos(p);
  return {
    x: Math.sin(yawRad) * cy * radius,
    y: Math.sin(p) * radius,
    z: Math.cos(yawRad) * cy * radius
  };
}

export function shouldResumeAutoRotate(angularSpeed: number): boolean {
  return Math.abs(angularSpeed) < AUTO_ROTATE_RESUME_SPEED;
}

export function localToNdc(x: number, y: number, width: number, height: number): Vec3 {
  if (width <= 0 || height <= 0) {
    return { x: 0, y: 0, z: 0 };
  }
  return {
    x: (x / width) * 2 - 1,
    y: 1 - (y / height) * 2,
    z: 0
  };
}

export const BACK_POINT_SCALE: number = 0.38;
export const FRONT_POINT_SCALE: number = 1.12;
export const BACK_POINT_ALPHA: number = 0.16;
export const FRONT_POINT_ALPHA: number = 1;
export const SELECTED_POINT_SCALE_BOOST: number = 1.35;

/** 球心在原点时，点法线与相机方向的对齐程度：1 正面，-1 背面。 */
export function sphereFacing(point: Vec3, eye: Vec3): number {
  const el = Math.sqrt(eye.x * eye.x + eye.y * eye.y + eye.z * eye.z);
  const pl = Math.sqrt(point.x * point.x + point.y * point.y + point.z * point.z);
  if (el < 1e-6 || pl < 1e-6) {
    return 0;
  }
  return (point.x * eye.x + point.y * eye.y + point.z * eye.z) / (el * pl);
}

export function pointFacingScale(facing: number): number {
  const t = clamp01((facing + 1) * 0.5);
  return BACK_POINT_SCALE + (FRONT_POINT_SCALE - BACK_POINT_SCALE) * t;
}

export function pointFacingAlpha(facing: number): number {
  const t = clamp01((facing + 1) * 0.5);
  const k = t * t;
  return BACK_POINT_ALPHA + (FRONT_POINT_ALPHA - BACK_POINT_ALPHA) * k;
}

export function worldToCanvas(point: Vec3, eye: Vec3, fovRad: number, canvasSize: number): Vec3 {
  const axes = cameraAxesFromEye(eye);
  const rx = point.x - eye.x;
  const ry = point.y - eye.y;
  const rz = point.z - eye.z;
  const cx = rx * axes.right.x + ry * axes.right.y + rz * axes.right.z;
  const cy = rx * axes.up.x + ry * axes.up.y + rz * axes.up.z;
  const cz = rx * axes.back.x + ry * axes.back.y + rz * axes.back.z;
  if (cz >= -1e-4 || canvasSize <= 0) {
    return { x: canvasSize * 0.5, y: canvasSize * 0.5, z: 1 };
  }
  const f = 1 / Math.tan(fovRad * 0.5);
  const ndcX = f * cx / (-cz);
  const ndcY = f * cy / (-cz);
  return {
    x: (ndcX + 1) * 0.5 * canvasSize,
    y: (1 - ndcY) * 0.5 * canvasSize,
    z: cz
  };
}

export function orbitSensitivity(canvasSize: number): number {
  const size = canvasSize > 8 ? canvasSize : DEFAULT_ORBIT_CANVAS;
  return 1 / (size * 0.54);
}

export function applyOrbitPan(yaw: number, pitch: number, dxVp: number, dyVp: number,
  sensitivity: number): Vec3 {
  return {
    x: yaw - dxVp * sensitivity,
    y: clampOrbitPitch(pitch + dyVp * sensitivity),
    z: 0
  };
}

export function clampOrbitSpeed(speed: number): number {
  if (speed > MAX_ORBIT_SPEED_RAD) {
    return MAX_ORBIT_SPEED_RAD;
  }
  if (speed < -MAX_ORBIT_SPEED_RAD) {
    return -MAX_ORBIT_SPEED_RAD;
  }
  return speed;
}

export function decayOrbitSpeed(speed: number, dt: number): number {
  if (dt <= 0) {
    return speed;
  }
  return speed * Math.exp(-dt / ORBIT_COAST_TAU_S);
}

export function pickNearestFrontKey(keys: string[], layoutX: number, layoutY: number, yaw: number,
  pitch: number, canvasSize: number, hitRadius: number): string {
  const eye = orbitEye(yaw, pitch);
  let best = '';
  let bestD = hitRadius * hitRadius;
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    if (key.length === 0) {
      continue;
    }
    const p = deviceSpherePointForStableKey(key);
    if (sphereFacing(p, eye) <= 0) {
      continue;
    }
    const proj = worldToCanvas(p, eye, CAMERA_FOV_RAD, canvasSize);
    if (proj.z >= 0) {
      continue;
    }
    const dx = layoutX - proj.x;
    const dy = layoutY - proj.y;
    const d2 = dx * dx + dy * dy;
    if (d2 < bestD) {
      bestD = d2;
      best = key;
    }
  }
  return best;
}

function clamp01(value: number): number {
  if (value < 0) {
    return 0;
  }
  if (value > 1) {
    return 1;
  }
  return value;
}

interface CameraAxes {
  right: Vec3;
  up: Vec3;
  back: Vec3;
}

function cameraAxesFromEye(eye: Vec3): CameraAxes {
  const len = Math.sqrt(eye.x * eye.x + eye.y * eye.y + eye.z * eye.z);
  const back: Vec3 = len < 1e-6 ? { x: 0, y: 0, z: 1 } : { x: eye.x / len, y: eye.y / len, z: eye.z / len };
  let rx = back.z;
  let ry = 0;
  let rz = -back.x;
  const rl = Math.sqrt(rx * rx + ry * ry + rz * rz);
  if (rl < 1e-6) {
    rx = 1;
    ry = 0;
    rz = 0;
  } else {
    rx = rx / rl;
    ry = ry / rl;
    rz = rz / rl;
  }
  const right: Vec3 = { x: rx, y: ry, z: rz };
  const up: Vec3 = {
    x: back.y * rz - back.z * ry,
    y: back.z * rx - back.x * rz,
    z: back.x * ry - back.y * rx
  };
  return { right: right, up: up, back: back };
}
