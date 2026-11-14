export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

export const SPHERE_RADIUS: number = 1;

/** 黄金分割螺旋：把 total 个点均匀铺在半径 radius 的球面上。 */
export function goldenSpherePoint(index: number, total: number, radius: number): Vec3 {
  if (total <= 0) {
    return { x: 0, y: 0, z: 0 };
  }
  const t = (index + 0.5) / total;
  const phi = Math.acos(1 - 2 * t);
  const theta = Math.PI * (1 + Math.sqrt(5)) * index;
  return {
    x: Math.sin(phi) * Math.cos(theta) * radius,
    y: Math.cos(phi) * radius,
    z: Math.sin(phi) * Math.sin(theta) * radius
  };
}

/** 按列表序号均匀分布在球面上，与 RSSI/设备 ID 无关，避免假方位含义 */
export function deviceSpherePointForIndex(index: number, total: number): Vec3 {
  return goldenSpherePoint(index, total, 0.85);
}

export function deviceSpherePointForStableKey(deviceKey: string, radius: number = SPHERE_RADIUS): Vec3 {
  let h1 = 2166136261;
  let h2 = 16777619;
  for (let i = 0; i < deviceKey.length; i++) {
    const c = deviceKey.charCodeAt(i);
    h1 = ((h1 ^ c) * 16777619) >>> 0;
    h2 = ((h2 ^ c) * 2246822519) >>> 0;
  }
  const u = ((h1 >>> 0) % 100000) / 100000;
  const y = 1 - 2 * u;
  const rAtY = Math.sqrt(Math.max(0, 1 - y * y));
  const golden = (1 + Math.sqrt(5)) / 2;
  const theta = 2 * Math.PI * ((((h2 >>> 0) / 4294967296) * golden) % 1);
  return {
    x: Math.cos(theta) * rAtY * radius,
    y: y * radius,
    z: Math.sin(theta) * rAtY * radius
  };
}

/** 按 deviceKey 哈希固定球面位置，列表增删时单点不跳动 */
export function deviceSpherePointForKey(deviceKey: string): Vec3 {
  let h1 = 2166136261;
  let h2 = 16777619;
  for (let i = 0; i < deviceKey.length; i++) {
    const c = deviceKey.charCodeAt(i);
    h1 = ((h1 ^ c) * 16777619) >>> 0;
    h2 = ((h2 ^ c) * 2246822519) >>> 0;
  }
  const u = ((h1 >>> 0) % 10000) / 10000;
  const v = ((h2 >>> 0) % 10000) / 10000;
  const phi = Math.acos(1 - 2 * u);
  const theta = 2 * Math.PI * v;
  const r = 0.85;
  return {
    x: Math.sin(phi) * Math.cos(theta) * r,
    y: Math.cos(phi) * r,
    z: Math.sin(phi) * Math.sin(theta) * r
  };
}

export function ripplePhaseOffset(deviceId: string): number {
  let hash = 0;
  for (let i = 0; i < deviceId.length; i++) {
    hash = (hash * 13 + deviceId.charCodeAt(i)) % 997;
  }
  return (hash % 100) / 100;
}
