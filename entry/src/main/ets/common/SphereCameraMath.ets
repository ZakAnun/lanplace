import { Vec3 } from './RadarDeviceLayout';

export const TAP_SLOP_VP: number = 8;
export const PITCH_LIMIT_RAD: number = 89 * Math.PI / 180;
export const AUTO_ROTATE_RESUME_SPEED: number = 0.15;
export const ORBIT_RADIUS: number = 3;
export const AUTO_ROTATE_YAW_SPEED: number = 0.18;

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
