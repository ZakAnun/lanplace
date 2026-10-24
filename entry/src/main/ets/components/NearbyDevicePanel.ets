import { AppleTheme } from '../common/AppleTheme';
import {
  computeRadarCanvasSize,
  LANDSCAPE_RIGHT_RAIL_WIDTH,
  radarZoneWidth
} from '../common/RadarLayoutHelper';
import { DeviceLinkState, ScannedDevice } from '../model/ScannedDevice';
import { BleDiscoveryRadar } from './BleDiscoveryRadar';
import { RadarDeviceInfoBar } from './RadarDeviceInfoBar';

@Component
export struct NearbyDevicePanel {
  @Prop @Watch('onDevicesChanged') devices: ScannedDevice[] = [];
  @Prop @Watch('onLayoutModeChanged') isLandscapeLayout: boolean = false;
  @Prop scanning: boolean = false;
  @Prop active: boolean = true;
  @State selectedDeviceId: string = '';
  @State layoutWidth: number = 0;
  @State layoutHeight: number = 0;
  @State radarCanvasSize: number = 280;
  @BuilderParam topBanner: () => void = this.emptySlot;
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
      this.selectedDeviceId = '';
      return;
    }
    let found = false;
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].deviceId === this.selectedDeviceId) {
        found = true;
        break;
      }
    }
    if (!found) {
      this.selectedDeviceId = '';
    }
  }

  private selectedDevice(): ScannedDevice {
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].deviceId === this.selectedDeviceId) {
        return this.devices[i];
      }
    }
    return {
      deviceId: '',
      displayName: '',
      rssi: 0,
      connectable: false,
      detailLine: '',
      advertSummary: '',
      linkState: DeviceLinkState.Discovered
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
  hintText() {
    if (this.devices.length > 0) {
      Text($r('app.string.browse_device_count', this.devices.length))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
        .textAlign(TextAlign.Center)
    } else if (this.scanning) {
      Text($r('app.string.scanning_hint'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
        .textAlign(TextAlign.Center)
    } else {
      Text($r('app.string.empty_list'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  radarBlock() {
    Stack({ alignContent: Alignment.Center }) {
      BleDiscoveryRadar({
        active: this.active,
        devices: this.devices,
        selectedDeviceId: $selectedDeviceId,
        canvasSize: this.radarCanvasSize
      })
    }
    .width('100%')
    .height(this.radarCanvasSize)
    .alignContent(Alignment.Center)
  }

  @Builder
  radarStage() {
    Column({ space: 8 }) {
      this.topBanner()
      this.hintText()
      Column() {
        this.radarBlock()
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
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

      RadarDeviceInfoBar({ device: this.selectedDevice() })
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
