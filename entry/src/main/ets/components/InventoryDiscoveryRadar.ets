import { AppleTheme } from '../common/AppleTheme';
import { deviceSpherePointForKey, ripplePhaseOffset } from '../common/RadarDeviceLayout';
import {
  HomeInventoryDevice,
  InventoryDeviceKind
} from '../model/HomeInventoryDevice';

interface ProjectedPoint {
  sx: number;
  sy: number;
  z: number;
}

interface DeviceDrawItem {
  device: HomeInventoryDevice;
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
const LAN_RGB: string = '230, 134, 25';
const BLE_RGB: string = '0, 102, 204';

@Component
export struct InventoryDiscoveryRadar {
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @Prop @Watch('onDevicesChanged') devices: HomeInventoryDevice[] = [];
  @Link selectedDeviceKey: string;
  @Prop @Watch('onCanvasSizeChanged') canvasSize: number = DEFAULT_CANVAS_SIZE;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private tickTimerId: number = -1;
  private startMs: number = 0;
  private clockStarted: boolean = false;
  private disposed: boolean = false;
  private canvasReady: boolean = false;
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
      alive.add(this.devices[i].deviceKey);
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

  private rgbForDevice(device: HomeInventoryDevice): string {
    return device.kind === InventoryDeviceKind.Lan ? LAN_RGB : BLE_RGB;
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

  private fadeInForDevice(deviceKey: string): number {
    const now = Date.now();
    if (!this.deviceFirstSeenMs.has(deviceKey)) {
      this.deviceFirstSeenMs.set(deviceKey, now);
    }
    const seen = this.deviceFirstSeenMs.get(deviceKey) ?? now;
    const age = now - seen;
    return Math.min(1, age / 520);
  }

  private drawRipples(ctx: CanvasRenderingContext2D, sx: number, sy: number, elapsed: number,
    deviceKey: string, fade: number, selected: boolean, depthFade: number, rgb: string): void {
    const offset = ripplePhaseOffset(deviceKey);
    for (let w = 0; w < 2; w++) {
      const t = (elapsed / RIPPLE_PERIOD + offset + w * 0.5) % 1;
      const radius = 8 + t * (selected ? 32 : 24);
      const alpha = (1 - t) * 0.26 * fade * depthFade;
      ctx.beginPath();
      ctx.arc(sx, sy, radius * this.layoutScale(), 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(${rgb}, ${alpha})`;
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  }

  private drawHubLinks(ctx: CanvasRenderingContext2D, items: DeviceDrawItem[], cx: number, cy: number,
    elapsed: number): void {
    const breathe = 0.45 + 0.55 * Math.sin(elapsed * 1.2);
    const scale = this.layoutScale();
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const depth = this.depthFade(item.z);
      const rgb = this.rgbForDevice(item.device);
      const alpha = (0.06 + depth * 0.1) * breathe * item.fade;
      const pulseT = (elapsed * 0.85 + ripplePhaseOffset(item.device.deviceKey) * 0.3) % 1;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(item.sx, item.sy);
      ctx.strokeStyle = `rgba(${rgb}, ${alpha})`;
      ctx.lineWidth = 1 * scale;
      ctx.stroke();

      const px = cx + (item.sx - cx) * pulseT;
      const py = cy + (item.sy - cy) * pulseT;
      ctx.beginPath();
      ctx.arc(px, py, 2.5 * scale, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${rgb}, ${0.35 * item.fade * depth})`;
      ctx.fill();
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
    const rgb = this.rgbForDevice(item.device);
    const fillColor = item.device.kind === InventoryDeviceKind.Lan ? '#E68619' : AppleTheme.PRIMARY;

    this.drawRipples(ctx, sx, sy, elapsed, item.device.deviceKey, item.fade, selected, depth, rgb);

    ctx.beginPath();
    ctx.arc(sx, sy, coreR + 4 * scale, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(${rgb}, ${0.16 * fade})`;
    ctx.fill();

    ctx.beginPath();
    ctx.arc(sx, sy, coreR, 0, Math.PI * 2);
    ctx.fillStyle = fillColor;
    ctx.globalAlpha = fade;
    ctx.fill();
    ctx.globalAlpha = 1;

    if (selected) {
      ctx.beginPath();
      ctx.arc(sx, sy, coreR + 9 * scale, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(${rgb}, ${0.5 * fade})`;
      ctx.lineWidth = 2;
      ctx.stroke();
    }
  }

  private collectDeviceDrawItems(rotY: number, rotX: number, cx: number, cy: number): DeviceDrawItem[] {
    const items: DeviceDrawItem[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      const dev = this.devices[i];
      const v = deviceSpherePointForKey(dev.deviceKey);
      const p = this.project(v.x, v.y, v.z, rotY, rotX, cx, cy);
      items.push({
        device: dev,
        sx: p.sx,
        sy: p.sy,
        z: p.z,
        fade: this.fadeInForDevice(dev.deviceKey)
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

    if (deviceItems.length > 0) {
      this.drawHubLinks(ctx, deviceItems, cx, cy, elapsed);
    }

    for (let i = 0; i < deviceItems.length; i++) {
      const item = deviceItems[i];
      const selected = item.device.deviceKey === this.selectedDeviceKey;
      this.drawDevicePoint(ctx, item, elapsed, selected);
    }

    if (this.devices.length === 0) {
      this.drawRipples(ctx, cx, cy, elapsed, IDLE_HUB_RIPPLE_ID, 1, true, 1, BLE_RGB);
      this.drawRipples(ctx, cx, cy, elapsed + 0.4, IDLE_HUB_RIPPLE_ID + '_lan', 1, false, 1, LAN_RGB);
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
    let bestKey = '';
    const hitR = HIT_RADIUS * this.layoutScale();
    let bestDist = hitR * hitR;
    for (let i = 0; i < this.lastProjectedDevices.length; i++) {
      const item = this.lastProjectedDevices[i];
      const dx = mapped.sx - item.sx;
      const dy = mapped.sy - item.sy;
      const d2 = dx * dx + dy * dy;
      if (d2 < bestDist) {
        bestDist = d2;
        bestKey = item.device.deviceKey;
      }
    }
    if (bestKey.length > 0) {
      this.selectedDeviceKey = bestKey;
    }
  }

  @Builder
  centerHubOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(this.hubLayoutDiameter())
        .height(this.hubLayoutDiameter())
        .fill(AppleTheme.INK)
      Column() {
        Text('家')
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
