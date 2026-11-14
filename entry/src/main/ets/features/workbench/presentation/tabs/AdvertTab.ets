import { AppleTheme } from '../../../../shared/theme/AppleTheme';
import { AdvertHistory, AdvertSnapshot } from '../../../advert/domain/AdvertHistory';
import { RssiSample } from '../../../advert/domain/RssiRingBuffer';
import {
  ScanFilter,
  ScanFilterHolder,
  scanFilterIsActive
} from '../../../advert/domain/ScanFilter';

const SPARKLINE_HEIGHT: number = 120;
const SPARKLINE_REFRESH_MS: number = 500;
const RSSI_AXIS_MIN: number = -100;
const RSSI_AXIS_MAX: number = -30;

@Component
export struct AdvertTab {
  @Prop deviceKey: string = '';
  @State localName: string = '';
  @State flagsText: string = '';
  @State txPowerText: string = '';
  @State serviceUuids: string[] = [];
  @State manufacturerHex: string = '';
  @State serviceDataHex: string = '';
  @State filterUuid: string = '';
  @State filterManufacturerId: string = '';
  @State filterConnectableOnly: boolean = false;
  @State filterActive: boolean = false;
  @State samples: RssiSample[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private refreshTimerId: number = -1;
  private canvasReady: boolean = false;
  private disposed: boolean = false;
  private drawWidth: number = 0;
  private drawHeight: number = SPARKLINE_HEIGHT;

  aboutToAppear(): void {
    this.disposed = false;
    this.reload();
    this.startRefresh();
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.canvasReady = false;
    this.stopRefresh();
  }

  private startRefresh(): void {
    this.stopRefresh();
    this.refreshTimerId = setInterval(() => {
      if (this.disposed) {
        return;
      }
      this.reload();
    }, SPARKLINE_REFRESH_MS) as number;
  }

  private stopRefresh(): void {
    if (this.refreshTimerId >= 0) {
      clearInterval(this.refreshTimerId);
      this.refreshTimerId = -1;
    }
  }

  private reload(): void {
    this.reloadFilterSummary();
    this.samples = AdvertHistory.samples(this.deviceKey);
    const snap: AdvertSnapshot | null = AdvertHistory.snapshot(this.deviceKey);
    if (snap !== null) {
      this.localName = snap.localName;
      this.flagsText = snap.flags !== undefined ? `0x${snap.flags.toString(16)}` : '';
      this.txPowerText = snap.txPower !== undefined ? `${snap.txPower} dBm` : '';
      this.serviceUuids = snap.serviceUuids.slice();
      this.manufacturerHex = snap.manufacturerHex;
      this.serviceDataHex = snap.serviceDataHex;
    }
    if (this.canvasReady) {
      this.drawSparkline();
    }
  }

  private drawSparkline(): void {
    const ctx: CanvasRenderingContext2D = this.ctx;
    const contextW: number = ctx.width;
    const contextH: number = ctx.height;
    const w: number = contextW > 0 ? contextW : this.drawWidth;
    const h: number = contextH > 0 ? contextH : this.drawHeight;
    this.drawWidth = w;
    this.drawHeight = h;
    ctx.clearRect(0, 0, w, h);
    const pts: RssiSample[] = this.samples;
    if (pts.length === 0 || w <= 0 || h <= 0) {
      return;
    }

    ctx.strokeStyle = AppleTheme.HAIRLINE;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, h - 0.5);
    ctx.lineTo(w, h - 0.5);
    ctx.stroke();

    let minTs: number = pts[0].ts;
    let maxTs: number = pts[0].ts;
    let minR: number = pts[0].rssi;
    let maxR: number = pts[0].rssi;
    for (let i = 1; i < pts.length; i++) {
      if (pts[i].ts < minTs) {
        minTs = pts[i].ts;
      }
      if (pts[i].ts > maxTs) {
        maxTs = pts[i].ts;
      }
      if (pts[i].rssi < minR) {
        minR = pts[i].rssi;
      }
      if (pts[i].rssi > maxR) {
        maxR = pts[i].rssi;
      }
    }
    if (maxTs === minTs) {
      maxTs = minTs + 1;
    }
    minR = Math.min(minR, RSSI_AXIS_MIN);
    maxR = Math.max(maxR, RSSI_AXIS_MAX);
    if (maxR === minR) {
      maxR = minR + 1;
    }

    const pad: number = 8;
    const innerW: number = Math.max(1, w - pad * 2);
    const innerH: number = Math.max(1, h - pad * 2);
    const xs: number[] = [];
    const ys: number[] = [];
    for (let i = 0; i < pts.length; i++) {
      xs.push(pad + ((pts[i].ts - minTs) / (maxTs - minTs)) * innerW);
      ys.push(pad + ((maxR - pts[i].rssi) / (maxR - minR)) * innerH);
    }

    ctx.beginPath();
    ctx.moveTo(xs[0], h - pad);
    for (let i = 0; i < pts.length; i++) {
      ctx.lineTo(xs[i], ys[i]);
    }
    ctx.lineTo(xs[xs.length - 1], h - pad);
    ctx.closePath();
    ctx.fillStyle = `rgba(${AppleTheme.PRIMARY_RGB}, 0.16)`;
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(xs[0], ys[0]);
    for (let i = 1; i < pts.length; i++) {
      ctx.lineTo(xs[i], ys[i]);
    }
    ctx.strokeStyle = AppleTheme.PRIMARY;
    ctx.lineWidth = 1.5;
    ctx.stroke();

    const lastX: number = xs[xs.length - 1];
    const lastY: number = ys[ys.length - 1];
    ctx.beginPath();
    ctx.arc(lastX, lastY, 3.5, 0, Math.PI * 2);
    ctx.fillStyle = AppleTheme.PRIMARY;
    ctx.fill();
  }

  private reloadFilterSummary(): void {
    const filter: ScanFilter = ScanFilterHolder.current();
    const uuid: string = filter.serviceUuid !== undefined ? filter.serviceUuid.trim() : '';
    const mfg: string = filter.manufacturerId !== undefined ? filter.manufacturerId.trim() : '';
    this.filterUuid = uuid;
    this.filterManufacturerId = mfg;
    this.filterConnectableOnly = filter.connectableOnly;
    this.filterActive = scanFilterIsActive(filter);
  }

  private hasAdvertFields(): boolean {
    return this.localName.length > 0
      || this.flagsText.length > 0
      || this.txPowerText.length > 0
      || this.serviceUuids.length > 0
      || this.manufacturerHex.length > 0
      || this.serviceDataHex.length > 0;
  }

  @Builder
  advertFieldRow(label: Resource, value: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
      Text(value)
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.INK)
        .fontFamily('HarmonyOS Sans')
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  filterSummary() {
    Column({ space: 6 }) {
      Text($r('app.string.workbench_advert_filter'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
      if (!this.filterActive) {
        Text($r('app.string.workbench_advert_filter_none'))
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.INK)
          .width('100%')
      } else {
        if (this.filterUuid.length > 0) {
          this.advertFieldRow($r('app.string.inventory_filter_uuid'), this.filterUuid)
        }
        if (this.filterManufacturerId.length > 0) {
          this.advertFieldRow($r('app.string.inventory_filter_mfg'), this.filterManufacturerId)
        }
        if (this.filterConnectableOnly) {
          Text($r('app.string.inventory_filter_connectable'))
            .fontSize(AppleTheme.FONT_BODY)
            .fontColor(AppleTheme.INK)
            .width('100%')
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  advertFields() {
    Column({ space: 6 }) {
      this.filterSummary()
      if (this.localName.length > 0) {
        this.advertFieldRow($r('app.string.workbench_advert_local_name'), this.localName)
      }
      if (this.flagsText.length > 0) {
        this.advertFieldRow($r('app.string.workbench_advert_flags'), this.flagsText)
      }
      if (this.txPowerText.length > 0) {
        this.advertFieldRow($r('app.string.workbench_advert_tx_power'), this.txPowerText)
      }
      ForEach(this.serviceUuids, (uuid: string, index: number) => {
        this.advertFieldRow($r('app.string.workbench_advert_uuid'), uuid)
      }, (uuid: string, index: number) => `${index}-${uuid}`)
      if (this.manufacturerHex.length > 0) {
        this.advertFieldRow($r('app.string.workbench_advert_manufacturer'), this.manufacturerHex)
      }
      if (this.serviceDataHex.length > 0) {
        this.advertFieldRow($r('app.string.workbench_advert_service_data'), this.serviceDataHex)
      }
      if (!this.hasAdvertFields() && this.samples.length === 0) {
        Text($r('app.string.workbench_advert_empty'))
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Column({ space: 12 }) {
      this.advertFields()
      Text($r('app.string.workbench_advert_rssi'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
      Canvas(this.ctx)
        .width('100%')
        .height(SPARKLINE_HEIGHT)
        .backgroundColor(AppleTheme.CANVAS)
        .border({ width: 1, color: AppleTheme.HAIRLINE })
        .borderRadius(AppleTheme.RADIUS_LG)
        .accessibilityText($r('app.string.a11y_advert_rssi'))
        .onReady(() => {
          if (this.disposed) {
            return;
          }
          this.canvasReady = true;
          this.drawSparkline();
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
