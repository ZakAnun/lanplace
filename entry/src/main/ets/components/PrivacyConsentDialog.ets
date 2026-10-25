import { AppleTheme } from '../common/AppleTheme';

@CustomDialog
export struct PrivacyConsentDialog {
  controller?: CustomDialogController;
  onAgree: () => void = () => {};
  onDecline: () => void = () => {};
  onOpenPolicy: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.privacy_dialog_title'))
        .fontSize(AppleTheme.FONT_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
      Text($r('app.string.privacy_dialog_body'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.INK)
        .lineHeight(25)
      Text($r('app.string.privacy_dialog_open_policy'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.PRIMARY)
        .onClick(() => {
          this.onOpenPolicy();
        })
      Row({ space: 12 }) {
        Button($r('app.string.privacy_dialog_decline'))
          .layoutWeight(1)
          .backgroundColor(AppleTheme.CANVAS)
          .fontColor(AppleTheme.PRIMARY)
          .border({ width: 1, color: AppleTheme.PRIMARY })
          .borderRadius(AppleTheme.RADIUS_PILL)
          .onClick(() => {
            this.onDecline();
          })
        Button($r('app.string.privacy_dialog_agree'))
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
