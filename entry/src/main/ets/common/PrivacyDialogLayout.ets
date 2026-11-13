import { AppleTheme } from './AppleTheme';

/** 弹窗外上下各留出的边距（vp），避免贴齐状态栏/导航条 */
export const PRIVACY_DIALOG_OUTER_MARGIN_VP: number = 32;
export const PRIVACY_DIALOG_PADDING_VP: number = 24;
export const PRIVACY_DIALOG_STACK_SPACE_VP: number = 16;
export const PRIVACY_BODY_SCROLL_MIN_VP: number = 96;
export const PRIVACY_BODY_SCROLL_MAX_CAP_VP: number = 420;

/** 除正文 Scroll 外的固定高度：padding + 标题 + 政策链接 + 按钮 + 间距 */
export function privacyDialogChromeHeightVp(): number {
  return PRIVACY_DIALOG_PADDING_VP * 2 +
    AppleTheme.FONT_TITLE +
    PRIVACY_DIALOG_STACK_SPACE_VP * 3 +
    AppleTheme.FONT_BODY +
    AppleTheme.TOUCH_TARGET_VP;
}

/** 弹窗整体 maxHeight，垂直居中且不贴边 */
export function computePrivacyDialogMaxHeightVp(windowHeightVp: number): number {
  const chrome = privacyDialogChromeHeightVp();
  if (windowHeightVp <= 0) {
    return chrome + PRIVACY_BODY_SCROLL_MIN_VP;
  }
  return Math.max(chrome + 48, windowHeightVp - PRIVACY_DIALOG_OUTER_MARGIN_VP * 2);
}

/** 正文 Scroll 的 maxHeight，保证标题与按钮始终留在弹窗内 */
export function computePrivacyBodyScrollMaxHeightVp(windowHeightVp: number): number {
  if (windowHeightVp <= 0) {
    return PRIVACY_BODY_SCROLL_MIN_VP;
  }
  const available = computePrivacyDialogMaxHeightVp(windowHeightVp) - privacyDialogChromeHeightVp();
  return Math.max(48, Math.min(PRIVACY_BODY_SCROLL_MAX_CAP_VP, available));
}
