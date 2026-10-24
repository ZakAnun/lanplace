import { AppleTheme } from '../common/AppleTheme';
import { deviceSpherePointForIndex, ripplePhaseOffset } from '../common/RadarDeviceLayout';
import { ScannedDevice } from '../model/ScannedDevice';

interface ProjectedPoint {
  sx: number;
  sy: number;
  z: number;
}

interface DeviceDrawItem {
  device: ScannedDevice;
  sx: number;
  sy: number;
  z: number;
  fade: number;
}

const DEFAULT_CANVAS_SIZE: number = 280;
const FRAME_MS: number = 50;
const HIT_RADIUS: number = 26;
const ROT_SPEED: number = 0.14;
const RIPPLE_PERIOD: number = 3.2;
const IDLE_HUB_RIPPLE_ID: string = '__idle_hub__';

@Component
export struct BleDiscoveryRadar {
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @Prop @Watch('onDevicesChanged') devices: ScannedDevice[] = [];
  @Link selectedDeviceId: string;
  @Prop @Watch('onCanvasSizeChanged') canvasSize: number = DEFAULT_CANVAS_SIZE;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private tickTimerId: number = -1;
  private startMs: number = 0;
  private clockStarted: boolean = false;
  private disposed: boolean = false;
  private canvasReady: boolean = false;
  /** 与文档一致：绘制坐标以 onReady 后 context.width/height 为准（vp） */
  private drawWidth: number = DEFAULT_CANVAS_SIZE;
  private drawHeight: number = DEFAULT_CANVAS_SIZE;
  private deviceFirstSeenMs: Map<string, number> = new Map();
  private lastProjectedDevices: DeviceDrawItem[] = [];

  aboutToAppear(): void {
    this.disposed = false;
    if (this.active && this.canvasReady) {
      this.startTick();
    }
  }

  onCanvasSizeChanged(): void {
    if (this.disposed || !this.active) {
      return;
    }
    this.syncCanvasMetrics();
    this.drawFrame();
    if (this.tickTimerId < 0 && this.canvasReady) {
      this.startTick();
    }
  }

  onActiveChanged(): void {
    if (this.disposed) {
      return;
    }
    if (this.active) {
      this.startTick();
    } else {
      this.stopTick();
    }
  }

  onDevicesChanged(): void {
    const alive: Set<string> = new Set();
    for (let i = 0; i < this.devices.length; i++) {
      alive.add(this.devices[i].deviceId);
    }
    const removeIds: string[] = [];
    this.deviceFirstSeenMs.forEach((_seenAt: number, key: string) => {
      if (!alive.has(key)) {
        removeIds.push(key);
      }
    });
    for (let i = 0; i < removeIds.length; i++) {
      this.deviceFirstSeenMs.delete(removeIds[i]);
    }
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.canvasReady = false;
    this.stopTick();
  }

  private syncCanvasMetrics(): void {
    const contextW = this.ctx.width;
    const contextH = this.ctx.height;
    if (contextW > 0 && contextH > 0) {
      this.drawWidth = contextW;
      this.drawHeight = contextH;
      return;
    }
    this.drawWidth = this.canvasSize;
    this.drawHeight = this.canvasSize;
  }

  private layoutScale(): number {
    return this.drawWidth / DEFAULT_CANVAS_SIZE;
  }

  /** 布局 vp 中心映射到 Canvas 绘制坐标（与组件 width/height 对齐） */
  private centerDrawX(): number {
    const layoutSize = Math.max(this.canvasSize, 1);
    return (layoutSize / 2) * (this.drawWidth / layoutSize);
  }

  private centerDrawY(): number {
    const layoutSize = Math.max(this.canvasSize, 1);
    return (layoutSize / 2) * (this.drawHeight / layoutSize);
  }

  private hubLayoutDiameter(): number {
    return 48 * (this.canvasSize / DEFAULT_CANVAS_SIZE);
  }

  private hubLayoutFontSize(): number {
    return Math.max(11, 14 * (this.canvasSize / DEFAULT_CANVAS_SIZE));
  }

  private stopTick(): void {
    if (this.tickTimerId >= 0) {
      clearInterval(this.tickTimerId);
      this.tickTimerId = -1;
    }
  }

  private startTick(): void {
    if (!this.canvasReady || !this.active || this.disposed) {
      return;
    }
    this.stopTick();
    this.syncCanvasMetrics();
    this.drawFrame();
    this.tickTimerId = setInterval(() => {
      if (this.disposed || !this.active) {
        return;
      }
      this.drawFrame();
    }, FRAME_MS) as number;
  }

  private project(x: number, y: number, z: number, rotY: number, rotX: number, cx: number,
    cy: number): ProjectedPoint {
    let xr = x * Math.cos(rotY) - z * Math.sin(rotY);
    let zr = x * Math.sin(rotY) + z * Math.cos(rotY);
    let yr = y;
    let y2 = yr * Math.cos(rotX) - zr * Math.sin(rotX);
    let z2 = yr * Math.sin(rotX) + zr * Math.cos(rotX);
    const perspective = 300 / (300 + z2 * 130);
    const sphereScale = this.layoutScale();
    return {
      sx: cx + xr * 98 * sphereScale * perspective,
      sy: cy + y2 * 98 * sphereScale * perspective,
      z: z2
    };
  }

  private depthFade(z: number): number {
    return Math.max(0.42, Math.min(1, 0.58 + z * 0.42));
  }

  private fadeInForDevice(deviceId: string): number {
    const now = Date.now();
    if (!this.deviceFirstSeenMs.has(deviceId)) {
      this.deviceFirstSeenMs.set(deviceId, now);
    }
    const seen = this.deviceFirstSeenMs.get(deviceId) ?? now;
    const age = now - seen;
    return Math.min(1, age / 520);
  }

  private drawRipples(ctx: CanvasRenderingContext2D, sx: number, sy: number, elapsed: number,
    deviceId: string, fade: number, selected: boolean, depthFade: number): void {
    const offset = ripplePhaseOffset(deviceId);
    for (let w = 0; w < 2; w++) {
      const t = (elapsed / RIPPLE_PERIOD + offset + w * 0.5) % 1;
      const radius = 8 + t * (selected ? 32 : 24);
      const alpha = (1 - t) * 0.26 * fade * depthFade;
      ctx.beginPath();
      ctx.arc(sx, sy, radius * this.layoutScale(), 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(0, 102, 204, ${alpha})`;
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  }

  private drawDevicePoint(ctx: CanvasRenderingContext2D, item: DeviceDrawItem, elapsed: number,
    selected: boolean): void {
    const depth = this.depthFade(item.z);
    const fade = item.fade * depth;
    const sx = item.sx;
    const sy = item.sy;
    const scale = this.layoutScale();
    const coreR = (selected ? 7.5 : 6) * scale;

    this.drawRipples(ctx, sx, sy, elapsed, item.device.deviceId, item.fade, selected, depth);

    ctx.beginPath();
    ctx.arc(sx, sy, coreR + 4 * scale, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(0, 102, 204, ${0.16 * fade})`;
    ctx.fill();

    ctx.beginPath();
    ctx.arc(sx, sy, coreR, 0, Math.PI * 2);
    ctx.fillStyle = AppleTheme.PRIMARY;
    ctx.globalAlpha = fade;
    ctx.fill();
    ctx.globalAlpha = 1;

    if (selected) {
      ctx.beginPath();
      ctx.arc(sx, sy, coreR + 9 * scale, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(0, 102, 204, ${0.5 * fade})`;
      ctx.lineWidth = 2;
      ctx.stroke();
    }
  }

  private collectDeviceDrawItems(rotY: number, rotX: number, cx: number, cy: number): DeviceDrawItem[] {
    const items: DeviceDrawItem[] = [];
    const total = this.devices.length;
    for (let i = 0; i < total; i++) {
      const dev = this.devices[i];
      const v = deviceSpherePointForIndex(i, total);
      const p = this.project(v.x, v.y, v.z, rotY, rotX, cx, cy);
      items.push({
        device: dev,
        sx: p.sx,
        sy: p.sy,
        z: p.z,
        fade: this.fadeInForDevice(dev.deviceId)
      });
    }
    items.sort((a, b) => a.z - b.z);
    return items;
  }

  private drawFrame(): void {
    this.syncCanvasMetrics();
    const ctx = this.ctx;
    const w = this.drawWidth;
    const h = this.drawHeight;
    const cx = this.centerDrawX();
    const cy = this.centerDrawY();
    const elapsed = (Date.now() - this.startMs) / 1000;
    const rotY = elapsed * ROT_SPEED;
    const rotX = 0.38 + Math.sin(elapsed * 0.18) * 0.08;

    ctx.clearRect(0, 0, w, h);

    const deviceItems = this.collectDeviceDrawItems(rotY, rotX, cx, cy);
    this.lastProjectedDevices = deviceItems;

    for (let i = 0; i < deviceItems.length; i++) {
      const item = deviceItems[i];
      const selected = item.device.deviceId === this.selectedDeviceId;
      this.drawDevicePoint(ctx, item, elapsed, selected);
    }

    if (this.devices.length === 0) {
      this.drawRipples(ctx, cx, cy, elapsed, IDLE_HUB_RIPPLE_ID, 1, true, 1);
    }
  }

  private mapClickToDrawSpace(x: number, y: number): ProjectedPoint {
    const layoutW = this.canvasSize;
    const layoutH = this.canvasSize;
    if (layoutW <= 0 || layoutH <= 0) {
      return { sx: x, sy: y, z: 0 };
    }
    return {
      sx: x * (this.drawWidth / layoutW),
      sy: y * (this.drawHeight / layoutH),
      z: 0
    };
  }

  private handleTapAt(x: number, y: number): void {
    const mapped = this.mapClickToDrawSpace(x, y);
    let bestId = '';
    const hitR = HIT_RADIUS * this.layoutScale();
    let bestDist = hitR * hitR;
    for (let i = 0; i < this.lastProjectedDevices.length; i++) {
      const item = this.lastProjectedDevices[i];
      const dx = mapped.sx - item.sx;
      const dy = mapped.sy - item.sy;
      const d2 = dx * dx + dy * dy;
      if (d2 < bestDist) {
        bestDist = d2;
        bestId = item.device.deviceId;
      }
    }
    if (bestId.length > 0) {
      this.selectedDeviceId = bestId;
    }
  }

  @Builder
  centerHubOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(this.hubLayoutDiameter())
        .height(this.hubLayoutDiameter())
        .fill(AppleTheme.PRIMARY)
      Column() {
        Text('BT')
          .fontSize(this.hubLayoutFontSize())
          .fontWeight(FontWeight.Bold)
          .fontColor(AppleTheme.CANVAS)
          .textAlign(TextAlign.Center)
          .lineHeight(this.hubLayoutFontSize())
          .maxLines(1)
      }
      .width(this.hubLayoutDiameter())
      .height(this.hubLayoutDiameter())
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width(this.hubLayoutDiameter())
    .height(this.hubLayoutDiameter())
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Canvas(this.ctx)
        .width(this.canvasSize)
        .height(this.canvasSize)
        .accessibilityLevel('no')
        .onReady(() => {
          if (this.disposed) {
            return;
          }
          this.canvasReady = true;
          this.syncCanvasMetrics();
          if (!this.clockStarted) {
            this.startMs = Date.now();
            this.clockStarted = true;
          }
          this.startTick();
        })

      this.centerHubOverlay()
    }
    .width(this.canvasSize)
    .height(this.canvasSize)
    .alignContent(Alignment.Center)
    .hitTestBehavior(HitTestMode.Default)
    .onClick((event: ClickEvent) => {
      this.handleTapAt(event.x, event.y);
    })
  }
}
