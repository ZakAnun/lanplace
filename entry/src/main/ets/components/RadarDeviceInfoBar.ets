import { AppleTheme } from '../common/AppleTheme';
import { DeviceLinkState, ScannedDevice } from '../model/ScannedDevice';

@Component
export struct RadarDeviceInfoBar {
  @Prop device: ScannedDevice = {
    deviceId: '',
    displayName: '',
    rssi: 0,
    connectable: false,
    detailLine: '',
    advertSummary: '',
    linkState: DeviceLinkState.Discovered
  };

  build() {
    if (this.device.deviceId.length === 0) {
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
        Text(this.device.displayName)
          .fontSize(AppleTheme.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppleTheme.INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.device.detailLine)
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.device.advertSummary.length > 0) {
          Text(this.device.advertSummary)
            .fontSize(AppleTheme.FONT_CAPTION)
            .fontColor(AppleTheme.INK_MUTED)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
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
