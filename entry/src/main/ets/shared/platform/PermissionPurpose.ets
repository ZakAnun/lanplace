/**
 * 华为 reason 文案规范：完整短句、告知场景、以句号结尾。
 * 运行时 reason 来自 string.json（系统弹窗直接展示）；本函数给单测与
 * scripts/verify_radar_layout_local.mjs 共用同一套规则，避免目录与算法漂移。
 */
export function isHuaweiPermissionReason(reason: string): boolean {
  if (reason.length === 0 || reason.length > 256) {
    return false;
  }
  const last = reason.substring(reason.length - 1);
  if (last !== '。' && last !== '.') {
    return false;
  }
  if (reason.indexOf('需要权限') >= 0 || reason.indexOf('获取权限') >= 0) {
    return false;
  }
  if (reason === '使用蓝牙。' || reason === '使用相机。') {
    return false;
  }
  return reason.indexOf('用于') >= 0 || reason.indexOf('Used to') >= 0;
}

/**
 * 首次系统弹窗被拒后等待；用户再次点击相关功能再走设置。
 * 与华为「拒绝后再次点击需拉起设置半模态」一致，故 alreadyAsked=true 时
 * 即便 dialogShown 仍为 true 也进 settings，而不是再等一次系统框。
 */
export function nextBluetoothPermissionStep(
  granted: boolean,
  dialogShown: boolean,
  alreadyAsked: boolean
): string {
  if (granted) {
    return 'done';
  }
  if (!alreadyAsked && dialogShown) {
    return 'wait';
  }
  return 'settings';
}
