import { AppleTheme } from '../common/AppleTheme';
import {
  HomeInventoryDevice,
  InventoryDeviceKind
} from '../model/HomeInventoryDevice';

@Component
export struct HomeInventoryDeviceInfoBar {
  @Prop device: HomeInventoryDevice = {
    deviceKey: '',
    kind: InventoryDeviceKind.Ble,
    displayName: '',
    detailLine: '',
    extraLine: '',
    rssi: 0
  };

  private kindLabel(): string {
    return this.device.kind === InventoryDeviceKind.Lan ? '局域网' : '蓝牙';
  }

  build() {
    if (this.device.deviceKey.length === 0) {
      Column() {
        Text($r('app.string.radar_tap_hint'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      .width('100%')
      .padding(16)
    } else {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(this.device.displayName)
            .fontSize(AppleTheme.FONT_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppleTheme.INK)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.kindLabel())
            .fontSize(AppleTheme.FONT_CAPTION)
            .fontColor(this.device.kind === InventoryDeviceKind.Lan ? AppleTheme.LAN_TEXT : AppleTheme.PRIMARY)
        }
        .width('100%')
        Text(this.device.detailLine)
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.device.extraLine.length > 0) {
          Text(this.device.extraLine)
            .fontSize(AppleTheme.FONT_CAPTION)
            .fontColor(AppleTheme.INK_MUTED)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        if (this.device.kind === InventoryDeviceKind.Ble && this.device.rssi !== 0) {
          Text($r('app.string.inventory_rssi_line', this.device.rssi))
            .fontSize(AppleTheme.FONT_CAPTION)
            .fontColor(AppleTheme.INK_MUTED)
            .width('100%')
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppleTheme.CANVAS)
      .borderRadius(AppleTheme.RADIUS_LG)
      .border({ width: 1, color: AppleTheme.HAIRLINE })
    }
  }
}
