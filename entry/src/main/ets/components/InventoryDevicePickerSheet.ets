import { AppleTheme } from '../common/AppleTheme';
import { computeDevicePickerScrollHeightVp, PICKER_ROW_GAP_VP } from '../common/DevicePickerSheetLayout';
import { HomeInventoryDevice, InventoryDeviceKind } from '../model/HomeInventoryDevice';

@Component
export struct InventoryDevicePickerSheet {
  @Prop devices: HomeInventoryDevice[] = [];
  @Prop listMaxHeight: number = 360;
  @Link selectedDeviceKey: string;
  onPick: () => void = (): void => {
  };
  onClose: () => void = (): void => {
  };

  private scrollAreaHeight(): number {
    return computeDevicePickerScrollHeightVp(this.devices.length, this.listMaxHeight);
  }

  /** 与 inventory_a11y_pick_lan / inventory_a11y_pick_ble 文案一致（accessibilityText 仅接受 string） */
  private rowA11yLabel(item: HomeInventoryDevice): string {
    if (item.kind === InventoryDeviceKind.Lan) {
      return `${item.displayName}，局域网`;
    }
    return `${item.displayName}，蓝牙`;
  }

  private accentColor(item: HomeInventoryDevice): string {
    return item.kind === InventoryDeviceKind.Lan ? AppleTheme.LAN_ACCENT : AppleTheme.PRIMARY;
  }

  private rowBackground(item: HomeInventoryDevice): string {
    if (this.selectedDeviceKey !== item.deviceKey) {
      return AppleTheme.CANVAS;
    }
    return item.kind === InventoryDeviceKind.Lan ? AppleTheme.ROW_SELECTED_LAN : AppleTheme.ROW_SELECTED;
  }

  @Builder
  kindBadge(item: HomeInventoryDevice) {
    if (item.kind === InventoryDeviceKind.Lan) {
      Text($r('app.string.inventory_kind_lan'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.LAN_TEXT)
        .constraintSize({ minWidth: 32 })
    } else {
      Text($r('app.string.inventory_kind_ble'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.PRIMARY)
        .constraintSize({ minWidth: 32 })
    }
  }

  build() {
    Column() {
      Text($r('app.string.inventory_picker_sheet_title'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 4, bottom: 16 })

      if (this.devices.length === 0) {
        Text($r('app.string.inventory_picker_empty'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 24, bottom: 24 })
      } else {
        Scroll() {
          Column({ space: PICKER_ROW_GAP_VP }) {
            ForEach(this.devices, (item: HomeInventoryDevice) => {
              Row({ space: 10 }) {
                this.kindBadge(item)
                Text(item.displayName)
                  .fontSize(AppleTheme.FONT_BODY)
                  .fontColor(AppleTheme.INK)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
              .height(AppleTheme.TOUCH_TARGET_VP)
              .alignItems(VerticalAlign.Center)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.rowBackground(item))
              .borderRadius(AppleTheme.RADIUS_PILL)
              .border({
                width: this.selectedDeviceKey === item.deviceKey ? 2 : 1,
                color: this.accentColor(item)
              })
              .accessibilityText(this.rowA11yLabel(item))
              .accessibilitySelected(this.selectedDeviceKey === item.deviceKey)
              .onClick(() => {
                this.selectedDeviceKey = item.deviceKey;
                this.onPick();
              })
            }, (item: HomeInventoryDevice) => item.deviceKey)
          }
          .width('100%')
        }
        .width('100%')
        .height(this.scrollAreaHeight())
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }

      Button($r('app.string.btn_close_sheet'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(AppleTheme.TOUCH_TARGET_VP)
        .padding(0)
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.PRIMARY)
        .backgroundColor(AppleTheme.CANVAS)
        .border({ width: 1, color: AppleTheme.PRIMARY })
        .borderRadius(AppleTheme.RADIUS_PILL)
        .margin({ top: 16, bottom: 12 })
        .onClick(() => {
          this.onClose();
        })
    }
    .width('100%')
    .padding({ top: 20, left: 20, right: 20, bottom: 12 })
    .backgroundColor(AppleTheme.CANVAS)
  }
}
