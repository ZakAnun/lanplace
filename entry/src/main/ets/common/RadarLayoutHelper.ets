const MIN_RADAR: number = 200;
const MAX_RADAR: number = 420;

/** 横屏右侧操作栏外宽，非左右等分 */
export const LANDSCAPE_RIGHT_RAIL_WIDTH: number = 176;

/** 横屏雷达相对中间列的内边距。不包含状态条和列表入口。 */
export const LANDSCAPE_RADAR_INSET_VP: number = 16;

export function isLandscapeLayout(width: number, height: number): boolean {
  return width > height;
}

export function radarZoneWidth(
  panelWidth: number,
  landscape: boolean,
  railWidth: number = LANDSCAPE_RIGHT_RAIL_WIDTH
): number {
  if (!landscape || panelWidth <= 0) {
    return panelWidth;
  }
  const gap = 12;
  return Math.max(160, panelWidth - railWidth - gap);
}

export function computeLandscapeLeftChromeVp(showPickerEntry: boolean): number {
  if (showPickerEntry) {
    return LANDSCAPE_RADAR_INSET_VP;
  }
  return LANDSCAPE_RADAR_INSET_VP;
}

export function computeRadarCanvasSize(
  radarZoneWidth: number,
  height: number,
  landscape: boolean,
  showPickerEntry: boolean = false,
  landscapeVerticalReserve: number = -1
): number {
  if (radarZoneWidth <= 0 || height <= 0) {
    return 280;
  }
  const landscapeReserve = landscapeVerticalReserve >= 0
    ? landscapeVerticalReserve
    : computeLandscapeLeftChromeVp(showPickerEntry);
  const reserveVertical = landscape ? landscapeReserve : 128;
  const byWidth = radarZoneWidth - 16;
  const byHeight = height - reserveVertical;
  return clampRadar(Math.min(byWidth, byHeight));
}

function clampRadar(value: number): number {
  return Math.max(MIN_RADAR, Math.min(MAX_RADAR, value));
}
