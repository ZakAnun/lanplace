import { AppleTheme } from '../common/AppleTheme';
import {
  computePrivacyBodyScrollMaxHeightVp,
  computePrivacyDialogMaxHeightVp
} from '../common/PrivacyDialogLayout';
import { WindowLayoutStore } from '../common/WindowLayoutStore';

@CustomDialog
export struct PrivacyConsentDialog {
  controller?: CustomDialogController;
  onAgree: () => void = () => {};
  onDecline: () => void = () => {};
  onOpenPolicy: () => void = () => {};
  @StorageLink(WindowLayoutStore.HEIGHT_KEY) mainWindowHeight: number = 0;

  private windowHeightVp(): number {
    if (this.mainWindowHeight <= 0) {
      return 0;
    }
    return this.getUIContext().px2vp(this.mainWindowHeight);
  }

  private bodyScrollMaxHeightVp(): number {
    return computePrivacyBodyScrollMaxHeightVp(this.windowHeightVp());
  }

  private dialogMaxHeightVp(): number {
    return computePrivacyDialogMaxHeightVp(this.windowHeightVp());
  }

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.privacy_dialog_title'))
        .fontSize(AppleTheme.FONT_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
        .width('100%')
      Scroll() {
        Text($r('app.string.privacy_dialog_body'))
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.INK)
          .lineHeight(25)
          .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: this.bodyScrollMaxHeightVp() })
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
      .edgeEffect(EdgeEffect.Spring)
      Text($r('app.string.privacy_dialog_open_policy'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.PRIMARY)
        .width('100%')
        .onClick(() => {
          this.onOpenPolicy();
        })
      Row({ space: 12 }) {
        Button($r('app.string.privacy_dialog_decline'))
          .layoutWeight(1)
          .height(AppleTheme.TOUCH_TARGET_VP)
          .backgroundColor(AppleTheme.CANVAS)
          .fontColor(AppleTheme.PRIMARY)
          .border({ width: 1, color: AppleTheme.PRIMARY })
          .borderRadius(AppleTheme.RADIUS_PILL)
          .onClick(() => {
            this.onDecline();
          })
        Button($r('app.string.privacy_dialog_agree'))
          .layoutWeight(1)
          .height(AppleTheme.TOUCH_TARGET_VP)
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
    .constraintSize({ maxHeight: this.dialogMaxHeightVp() })
  }
}
