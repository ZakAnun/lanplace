import { AppleTheme } from '../common/AppleTheme';

@CustomDialog
export struct PrivacyConsentDialog {
  controller?: CustomDialogController;
  onAgree: () => void = () => {};
  onDecline: () => void = () => {};
  onOpenPolicy: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text('隐私政策')
        .fontSize(AppleTheme.FONT_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
      Text('蓝域（BlueScopes）会在您主动扫描时展示周围蓝牙设备信息，数据仅在本机显示、不上传。请阅读隐私政策后选择是否继续。')
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.INK)
        .lineHeight(25)
      Text('查看隐私政策')
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.PRIMARY)
        .onClick(() => {
          this.onOpenPolicy();
        })
      Row({ space: 12 }) {
        Button('不同意')
          .layoutWeight(1)
          .backgroundColor(AppleTheme.CANVAS)
          .fontColor(AppleTheme.PRIMARY)
          .border({ width: 1, color: AppleTheme.PRIMARY })
          .borderRadius(AppleTheme.RADIUS_PILL)
          .onClick(() => {
            this.onDecline();
          })
        Button('同意并继续')
          .layoutWeight(1)
          .backgroundColor(AppleTheme.PRIMARY)
          .fontColor(AppleTheme.CANVAS)
          .borderRadius(AppleTheme.RADIUS_PILL)
          .onClick(() => {
            this.onAgree();
          })
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor(AppleTheme.CANVAS)
    .borderRadius(AppleTheme.RADIUS_LG)
    .width('90%')
  }
}
