import { AppleTheme } from '../common/AppleTheme';
import { computeDevicePickerListMaxHeightVp } from '../common/DevicePickerSheetLayout';
import {
  computeRadarCanvasSize,
  LANDSCAPE_RIGHT_RAIL_WIDTH,
  radarZoneWidth
} from '../common/RadarLayoutHelper';
import { HomeInventoryDevice, InventoryDeviceKind } from '../model/HomeInventoryDevice';
import { HomeInventoryDeviceInfoBar } from './HomeInventoryDeviceInfoBar';
import { InventoryDiscoveryRadar } from './InventoryDiscoveryRadar';
import { InventoryDevicePickerSheet } from './InventoryDevicePickerSheet';

@Component
export struct HomeInventoryPanel {
  @Prop @Watch('onDevicesChanged') devices: HomeInventoryDevice[] = [];
  @Prop @Watch('onLayoutModeChanged') isLandscapeLayout: boolean = false;
  @Prop scanning: boolean = false;
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @Prop windowHeightVp: number = 0;
  @Prop wifiSsid: string = '';
  @State selectedDeviceKey: string = '';
  @State layoutWidth: number = 0;
  @State layoutHeight: number = 0;
  @State radarCanvasSize: number = 280;
  @State showDevicePickerSheet: boolean = false;
  @BuilderParam footerIconAction: () => void = this.emptySlot;

  @Builder
  emptySlot() {
  }

  onLayoutModeChanged(): void {
    this.refreshRadarSize();
  }

  onDevicesChanged(): void {
    if (this.devices.length === 0) {
      this.showDevicePickerSheet = false;
    }
    this.syncSelection();
  }

  onActiveChanged(): void {
    if (!this.active) {
      this.showDevicePickerSheet = false;
    }
  }

  private devicePickerListMaxHeight(): number {
    const windowVp = this.windowHeightVp > 0 ? this.windowHeightVp : this.layoutHeight;
    return computeDevicePickerListMaxHeightVp(windowVp);
  }

  aboutToAppear(): void {
    this.syncSelection();
  }

  private syncSelection(): void {
    if (this.devices.length === 0) {
      this.selectedDeviceKey = '';
      return;
    }
    let found = false;
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].deviceKey === this.selectedDeviceKey) {
        found = true;
        break;
      }
    }
    if (!found) {
      this.selectedDeviceKey = '';
    }
  }

  private selectedDevice(): HomeInventoryDevice {
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].deviceKey === this.selectedDeviceKey) {
        return this.devices[i];
      }
    }
    return {
      deviceKey: '',
      kind: InventoryDeviceKind.Ble,
      displayName: '',
      detailLine: '',
      extraLine: '',
      rssi: 0
    };
  }

  private refreshRadarSize(): void {
    if (this.layoutWidth <= 0 || this.layoutHeight <= 0) {
      return;
    }
    const zoneW = radarZoneWidth(this.layoutWidth, this.isLandscapeLayout);
    this.radarCanvasSize = computeRadarCanvasSize(zoneW, this.layoutHeight, this.isLandscapeLayout);
  }

  @Builder
  wifiBanner() {
    if (this.wifiSsid.length > 0) {
      Text($r('app.string.inventory_wifi_ssid', this.wifiSsid))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  hintText() {
    if (this.devices.length > 0) {
      Text($r('app.string.inventory_device_count', this.devices.length))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
        .textAlign(TextAlign.Center)
    } else if (this.scanning) {
      Text($r('app.string.inventory_scanning_hint'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
        .textAlign(TextAlign.Center)
    } else {
      Text($r('app.string.inventory_empty'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  legendRow() {
    Row({ space: 16 }) {
      Row({ space: 6 }) {
        Circle().width(8).height(8).fill(AppleTheme.PRIMARY)
        Text($r('app.string.inventory_legend_ble'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
      }
      Row({ space: 6 }) {
        Circle().width(8).height(8).fill(AppleTheme.LAN_ACCENT)
        Text($r('app.string.inventory_legend_lan'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }

  @Builder
  radarBlock() {
    Stack({ alignContent: Alignment.Center }) {
      InventoryDiscoveryRadar({
        active: this.active,
        devices: this.devices,
        selectedDeviceKey: $selectedDeviceKey,
        canvasSize: this.radarCanvasSize
      })
    }
    .width('100%')
    .height(this.radarCanvasSize)
    .alignContent(Alignment.Center)
  }

  @Builder
  textDevicePickerEntry() {
    if (this.devices.length > 0) {
      Button($r('app.string.inventory_picker_show'))
        .type(ButtonType.Normal)
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.PRIMARY)
        .backgroundColor(Color.Transparent)
        .borderRadius(AppleTheme.RADIUS_PILL)
        .height(AppleTheme.TOUCH_TARGET_VP)
        .width('100%')
        .accessibilityText($r('app.string.inventory_a11y_picker_show'))
        .onClick(() => {
          this.showDevicePickerSheet = true;
        })
    }
  }

  private closeDevicePickerSheet(): void {
    this.showDevicePickerSheet = false;
  }

  private onDevicePickerSheetDisappear(): void {
    this.closeDevicePickerSheet();
  }

  private devicePickerSheetOptions(): SheetOptions {
    const options: SheetOptions = {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      preferType: SheetType.BOTTOM,
      maskColor: AppleTheme.SHEET_MASK,
      onDisappear: (): void => {
        this.onDevicePickerSheetDisappear();
      }
    };
    return options;
  }

  @Builder
  devicePickerSheetPanel() {
    InventoryDevicePickerSheet({
      devices: this.devices,
      listMaxHeight: this.devicePickerListMaxHeight(),
      selectedDeviceKey: $selectedDeviceKey,
      onPick: (): void => {
        this.closeDevicePickerSheet();
      },
      onClose: (): void => {
        this.closeDevicePickerSheet();
      }
    })
  }

  @Builder
  radarStage() {
    Column({ space: 8 }) {
      this.wifiBanner()
      Text($r('app.string.inventory_scope_hint'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .width('100%')
      this.hintText()
      this.legendRow()
      Column() {
        this.radarBlock()
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      this.textDevicePickerEntry()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  portraitBody() {
    Column({ space: 12 }) {
      Column() {
        this.radarStage()
      }
      .layoutWeight(1)
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      HomeInventoryDeviceInfoBar({ device: this.selectedDevice() })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  landscapeBody() {
    Row({ space: 12 }) {
      Column() {
        this.radarStage()
      }
      .layoutWeight(1)
      .height('100%')
      .alignItems(HorizontalAlign.Center)

      Column() {
        Blank()
          .layoutWeight(1)
        Row() {
          this.footerIconAction()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        Blank()
          .layoutWeight(1)
      }
      .width(LANDSCAPE_RIGHT_RAIL_WIDTH)
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
      if (this.isLandscapeLayout) {
        this.landscapeBody()
      } else {
        this.portraitBody()
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old, area) => {
      const w = area.width as number;
      const h = area.height as number;
      if (w > 0 && h > 0) {
        this.layoutWidth = w;
        this.layoutHeight = h;
        this.refreshRadarSize();
      }
    })
    .bindSheet(this.showDevicePickerSheet, this.devicePickerSheetPanel(), this.devicePickerSheetOptions())
  }
}
