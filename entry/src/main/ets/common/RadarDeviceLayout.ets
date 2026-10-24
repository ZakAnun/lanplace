export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

/** 按列表序号均匀分布在球面上，与 RSSI/设备 ID 无关，避免假方位含义 */
export function deviceSpherePointForIndex(index: number, total: number): Vec3 {
  if (total <= 0) {
    return { x: 0, y: 0, z: 0 };
  }
  const t = (index + 0.5) / total;
  const phi = Math.acos(1 - 2 * t);
  const theta = Math.PI * (1 + Math.sqrt(5)) * index;
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
