const MIN_RADAR: number = 200;
const MAX_RADAR: number = 420;

/** 横屏右侧详情 + 操作区固定宽度，非左右等分 */
export const LANDSCAPE_RIGHT_RAIL_WIDTH: number = 84;

export function isLandscapeLayout(width: number, height: number): boolean {
  return width > height;
}

export function radarZoneWidth(panelWidth: number, landscape: boolean): number {
  if (!landscape || panelWidth <= 0) {
    return panelWidth;
  }
  const gap = 12;
  return Math.max(160, panelWidth - LANDSCAPE_RIGHT_RAIL_WIDTH - gap);
}

export function computeRadarCanvasSize(radarZoneWidth: number, height: number, landscape: boolean): number {
  if (radarZoneWidth <= 0 || height <= 0) {
    return 280;
  }
  const reserveVertical = landscape ? 72 : 128;
  const byWidth = radarZoneWidth - 16;
  const byHeight = height - reserveVertical;
  return clampRadar(Math.min(byWidth, byHeight));
}

function clampRadar(value: number): number {
  return Math.max(MIN_RADAR, Math.min(MAX_RADAR, value));
}
