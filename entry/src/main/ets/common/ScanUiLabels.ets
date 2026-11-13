import { common } from '@kit.AbilityKit';

/** 扫描结果里的短文案。默认与 base 中文一致；页面启动时按系统语言覆盖。 */
export class ScanUiLabels {
  static unknownDevice: string = '未知设备';
  static unknownBleDevice: string = '未知蓝牙设备';
  static connectable: string = '可连接';
  static broadcastOnly: string = '仅广播';
  static a11yPickLan: string = '%1$s，局域网';
  static a11yPickBle: string = '%1$s，蓝牙';

  static load(context: common.Context): void {
    try {
      const rm = context.resourceManager;
      ScanUiLabels.unknownDevice = rm.getStringByNameSync('unknown_device');
      ScanUiLabels.unknownBleDevice = rm.getStringByNameSync('unknown_ble_device');
      ScanUiLabels.connectable = rm.getStringByNameSync('adv_connectable');
      ScanUiLabels.broadcastOnly = rm.getStringByNameSync('adv_broadcast_only');
      ScanUiLabels.a11yPickLan = rm.getStringByNameSync('inventory_a11y_pick_lan');
      ScanUiLabels.a11yPickBle = rm.getStringByNameSync('inventory_a11y_pick_ble');
    } catch (_err) {
      // 资源缺失时保留与 base 一致的中文默认值
    }
  }

  static connectableLabel(connectable: boolean): string {
    return connectable ? ScanUiLabels.connectable : ScanUiLabels.broadcastOnly;
  }

  static pickerA11y(name: string, isLan: boolean): string {
    const template = isLan ? ScanUiLabels.a11yPickLan : ScanUiLabels.a11yPickBle;
    return template.replace('%1$s', name);
  }
}
