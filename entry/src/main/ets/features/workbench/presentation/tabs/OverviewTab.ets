import { AppleTheme } from '../../../../shared/theme/AppleTheme';
import { InventoryDeviceKind } from '../../../discovery/domain/HomeInventoryDevice';

@Component
export struct OverviewTab {
  @Prop kind: InventoryDeviceKind = InventoryDeviceKind.Ble;
  @Prop displayName: string = '';
  @Prop detailLine: string = '';
  @Prop connectable: boolean = false;
  @Prop gattConnected: boolean = false;
  @Prop linkLost: boolean = false;
  @Prop connecting: boolean = false;
  onConnect: () => void = (): void => {
  };
  onDisconnect: () => void = (): void => {
  };
  onOpenGattDebug: () => void = (): void => {
  };

  private accentColor(): string {
    if (this.kind === InventoryDeviceKind.Lan) {
      return AppleTheme.LAN_TEXT;
    }
    return AppleTheme.PRIMARY;
  }

  @Builder
  bleActions() {
    if (!this.connectable) {
      Text($r('app.string.adv_broadcast_only'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
    } else if (this.gattConnected) {
      Button($r('app.string.workbench_btn_disconnect'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(AppleTheme.TOUCH_TARGET_VP)
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.PRIMARY)
        .backgroundColor(AppleTheme.CANVAS)
        .border({ width: 1, color: AppleTheme.PRIMARY })
        .borderRadius(AppleTheme.RADIUS_PILL)
        .onClick(() => {
          this.onDisconnect();
        })
      Button($r('app.string.workbench_btn_open_gatt'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(AppleTheme.TOUCH_TARGET_VP)
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.PRIMARY)
        .backgroundColor(AppleTheme.CANVAS)
        .border({ width: 1, color: AppleTheme.PRIMARY })
        .borderRadius(AppleTheme.RADIUS_PILL)
        .onClick(() => {
          this.onOpenGattDebug();
        })
    } else if (this.connecting) {
      Text($r('app.string.workbench_status_connecting'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
    } else if (this.linkLost) {
      Button($r('app.string.workbench_btn_reconnect'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(AppleTheme.TOUCH_TARGET_VP)
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.CANVAS)
        .backgroundColor(AppleTheme.PRIMARY)
        .borderRadius(AppleTheme.RADIUS_PILL)
        .onClick(() => {
          this.onConnect();
        })
    } else {
      Button($r('app.string.workbench_btn_connect'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(AppleTheme.TOUCH_TARGET_VP)
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.CANVAS)
        .backgroundColor(AppleTheme.PRIMARY)
        .borderRadius(AppleTheme.RADIUS_PILL)
        .onClick(() => {
          this.onConnect();
        })
    }
  }

  @Builder
  bleOverview() {
    Column({ space: 8 }) {
      if (this.displayName.length > 0) {
        Text(this.displayName)
          .fontSize(AppleTheme.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppleTheme.INK)
          .width('100%')
      }
      if (this.connecting) {
        Text($r('app.string.workbench_status_connecting'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      } else if (this.gattConnected) {
        Text($r('app.string.workbench_status_connected'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      } else if (this.linkLost) {
        Text($r('app.string.workbench_status_lost'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      } else {
        Text($r('app.string.workbench_status_disconnected'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      }
      if (this.connectable) {
        Text($r('app.string.adv_connectable'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      }
      this.bleActions()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  lanOverview() {
    Column({ space: 8 }) {
      if (this.displayName.length > 0) {
        Text(this.displayName)
          .fontSize(AppleTheme.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppleTheme.INK)
          .width('100%')
      }
      Text($r('app.string.inventory_legend_lan'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(this.accentColor())
        .width('100%')
      if (this.detailLine.length > 0) {
        Text(this.detailLine)
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .fontFamily('HarmonyOS Sans')
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      if (this.kind === InventoryDeviceKind.Lan) {
        this.lanOverview()
      } else {
        this.bleOverview()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
