import { AppleTheme } from './AppleTheme';

/** 设备列表 Scroll 区域高度上限（vp） */
export const PICKER_LIST_MAX_CAP_VP: number = 360;
export const PICKER_LIST_MIN_VP: number = 96;
export const PICKER_ROW_GAP_VP: number = 8;

const SHEET_PADDING_TOP_VP: number = 20;
const SHEET_PADDING_BOTTOM_VP: number = 12;
const TITLE_MARGIN_TOP_VP: number = 4;
const TITLE_MARGIN_BOTTOM_VP: number = 16;
const TITLE_LINE_VP: number = AppleTheme.FONT_BODY;
const CLOSE_MARGIN_TOP_VP: number = 16;
const CLOSE_MARGIN_BOTTOM_VP: number = 12;
/** 系统 dragBar + 顶部安全区预留（vp） */
const SHEET_DRAG_AND_SAFE_TOP_VP: number = 28;
/** 底部 sheet 与屏幕底边、导航栏预留（vp） */
const SHEET_SAFE_BOTTOM_VP: number = 48;

/** Sheet 内除 Scroll 列表外占用的固定高度（vp） */
export function devicePickerSheetChromeHeightVp(): number {
  return SHEET_PADDING_TOP_VP +
    TITLE_MARGIN_TOP_VP +
    TITLE_LINE_VP +
    TITLE_MARGIN_BOTTOM_VP +
    CLOSE_MARGIN_TOP_VP +
    AppleTheme.TOUCH_TARGET_VP +
    CLOSE_MARGIN_BOTTOM_VP +
    SHEET_PADDING_BOTTOM_VP +
    SHEET_DRAG_AND_SAFE_TOP_VP;
}

/** 根据窗口高度（vp）计算列表 Scroll 的 maxHeight */
export function computeDevicePickerListMaxHeightVp(windowHeightVp: number): number {
  if (windowHeightVp <= 0) {
    return PICKER_LIST_MAX_CAP_VP;
  }
  const chrome = devicePickerSheetChromeHeightVp();
  const available = windowHeightVp - chrome - SHEET_SAFE_BOTTOM_VP;
  return Math.max(PICKER_LIST_MIN_VP, Math.min(PICKER_LIST_MAX_CAP_VP, available));
}

/** 列表内容高度（vp），不超过 maxHeight */
export function computeDevicePickerScrollHeightVp(deviceCount: number, listMaxHeightVp: number): number {
  if (deviceCount <= 0) {
    return 0;
  }
  const row = AppleTheme.TOUCH_TARGET_VP;
  const content = deviceCount * row + Math.max(0, deviceCount - 1) * PICKER_ROW_GAP_VP;
  return Math.min(listMaxHeightVp, Math.max(row, content));
}
