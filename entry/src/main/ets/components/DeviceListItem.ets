import { ScannedDevice } from '../model/ScannedDevice';
import { AppleTheme } from '../common/AppleTheme';

@Component
export struct DeviceListItem {
  @Prop device: ScannedDevice = {
    deviceId: '',
    displayName: '',
    rssi: 0,
    connectable: false,
    detailLine: '',
    advertSummary: ''
  };

  build() {
    Column({ space: 6 }) {
      Text(this.device.displayName)
        .fontSize(AppleTheme.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
      Text(this.device.detailLine)
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
      if (this.device.advertSummary.length > 0) {
        Text(this.device.advertSummary)
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(24)
    .backgroundColor(AppleTheme.CANVAS)
    .borderRadius(AppleTheme.RADIUS_LG)
    .border({ width: 1, color: AppleTheme.HAIRLINE })
  }
}
