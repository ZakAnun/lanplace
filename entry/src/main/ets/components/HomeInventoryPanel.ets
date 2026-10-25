import { AppleTheme } from '../common/AppleTheme';
import {
  computeRadarCanvasSize,
  LANDSCAPE_RIGHT_RAIL_WIDTH,
  radarZoneWidth
} from '../common/RadarLayoutHelper';
import { HomeInventoryDevice, InventoryDeviceKind } from '../model/HomeInventoryDevice';
import { HomeInventoryDeviceInfoBar } from './HomeInventoryDeviceInfoBar';
import { InventoryDiscoveryRadar } from './InventoryDiscoveryRadar';

@Component
export struct HomeInventoryPanel {
  @Prop @Watch('onDevicesChanged') devices: HomeInventoryDevice[] = [];
  @Prop @Watch('onLayoutModeChanged') isLandscapeLayout: boolean = false;
  @Prop scanning: boolean = false;
  @Prop active: boolean = true;
  @Prop wifiSsid: string = '';
  @State selectedDeviceKey: string = '';
  @State layoutWidth: number = 0;
  @State layoutHeight: number = 0;
  @State radarCanvasSize: number = 280;
  @State showTextDevicePicker: boolean = false;
  @BuilderParam footerIconAction: () => void = this.emptySlot;

  @Builder
  emptySlot() {
  }

  onLayoutModeChanged(): void {
    this.refreshRadarSize();
  }

  onDevicesChanged(): void {
    this.syncSelection();
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
        Circle().width(8).height(8).fill('#E68619')
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
  textDevicePicker() {
    if (this.devices.length > 0) {
      Column({ space: 8 }) {
        Text(this.showTextDevicePicker
          ? $r('app.string.inventory_a11y_picker_hide')
          : $r('app.string.inventory_a11y_picker_show'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.PRIMARY)
          .textAlign(TextAlign.Center)
          .width('100%')
          .accessibilityText($r('app.string.inventory_a11y_picker_show'))
          .onClick(() => {
            this.showTextDevicePicker = !this.showTextDevicePicker;
          })
        if (this.showTextDevicePicker) {
          Column({ space: 6 }) {
            ForEach(this.devices, (item: HomeInventoryDevice) => {
              Button(item.displayName)
                .fontSize(AppleTheme.FONT_CAPTION)
                .fontColor(this.selectedDeviceKey === item.deviceKey ? AppleTheme.CANVAS : AppleTheme.PRIMARY)
                .backgroundColor(this.selectedDeviceKey === item.deviceKey ? AppleTheme.PRIMARY : AppleTheme.CANVAS)
                .border({ width: 1, color: AppleTheme.PRIMARY })
                .borderRadius(AppleTheme.RADIUS_PILL)
                .width('100%')
                .onClick(() => {
                  this.selectedDeviceKey = item.deviceKey;
                })
            }, (item: HomeInventoryDevice) => item.deviceKey)
          }
          .width('100%')
        }
      }
      .width('100%')
    }
  }

  @Builder
  radarStage() {
    Column({ space: 8 }) {
      this.wifiBanner()
      this.hintText()
      this.legendRow()
      Column() {
        this.radarBlock()
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      this.textDevicePicker()
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
  }
}
