import { AppleTheme } from '../common/AppleTheme';
import { deviceSpherePointForKey, ripplePhaseOffset } from '../common/RadarDeviceLayout';
import {
  canvasLayoutScale,
  clampDeviceOrbitLayout,
  evalQuadraticBezier,
  hubEdgeRadiusLayoutVp,
  layoutRadiusToDraw,
  minOrbitRadiusLayoutVp
} from '../common/RadarOrbitGeometry';
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

interface MotionAngles {
  rotY: number;
  rotX: number;
}

interface OrbitDrawMetrics {
  hubEdgeDraw: number;
  layoutToDraw: number;
  cxLayout: number;
  cyLayout: number;
}

const DEFAULT_CANVAS_SIZE: number = 280;
const FRAME_MS: number = 50;
const HIT_RADIUS: number = 26;
const RIPPLE_PERIOD: number = 3.2;
const HUB_DIAMETER_BASE: number = 34;
const HUB_FONT_BASE: number = 11;
const LINK_CTRL_FRAC: number = 0.45;
const LINK_CTRL_WOBBLE_VP: number = 8;
const IDLE_HUB_RIPPLE_ID: string = '__idle_hub__';

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

  /** 绘制缩放：layout 相对 280 基准 × 画布像素与 layout 尺寸比 */
  private layoutScale(): number {
    return this.canvasLayoutScaleFactor() * this.layoutToDrawScale();
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
    return HUB_DIAMETER_BASE * (this.canvasSize / DEFAULT_CANVAS_SIZE);
  }

  private hubLayoutFontSize(): number {
    return Math.max(AppleTheme.HUB_LABEL_MIN_FONT,
      HUB_FONT_BASE * (this.canvasSize / DEFAULT_CANVAS_SIZE));
  }

  private layoutToDrawScale(): number {
    const layout = Math.max(this.canvasSize, 1);
    const draw = this.drawWidth > 0 ? this.drawWidth : layout;
    return draw / layout;
  }

  private canvasLayoutScaleFactor(): number {
    return canvasLayoutScale(this.canvasSize, DEFAULT_CANVAS_SIZE);
  }

  private orbitDrawMetrics(): OrbitDrawMetrics {
    const layoutToDraw = this.layoutToDrawScale();
    const hubD = this.hubLayoutDiameter();
    const hubEdgeLayout = hubEdgeRadiusLayoutVp(hubD);
    return {
      hubEdgeDraw: layoutRadiusToDraw(hubEdgeLayout, layoutToDraw),
      layoutToDraw: layoutToDraw,
      cxLayout: this.canvasSize / 2,
      cyLayout: this.canvasSize / 2
    };
  }

  private layoutPointToDraw(sxLayout: number, syLayout: number, metrics: OrbitDrawMetrics, cx: number,
    cy: number): ProjectedPoint {
    const ox = (sxLayout - metrics.cxLayout) * metrics.layoutToDraw;
    const oy = (syLayout - metrics.cyLayout) * metrics.layoutToDraw;
    return { sx: cx + ox, sy: cy + oy, z: 0 };
  }

  private drawPointToLayout(sxDraw: number, syDraw: number, metrics: OrbitDrawMetrics, cx: number,
    cy: number): ProjectedPoint {
    const ox = (sxDraw - cx) / metrics.layoutToDraw;
    const oy = (syDraw - cy) / metrics.layoutToDraw;
    return {
      sx: metrics.cxLayout + ox,
      sy: metrics.cyLayout + oy,
      z: 0
    };
  }

  /** 平滑插值，用于连线和脉冲 */
  private smoothStep(t: number): number {
    const x = Math.max(0, Math.min(1, t));
    return x * x * (3 - 2 * x);
  }

  /** 非匀速「摆动」视角，替代单一匀速绕圈 */
  private motionAngles(elapsed: number): MotionAngles {
    const rotY = Math.sin(elapsed * 0.38) * 0.78 +
      Math.sin(elapsed * 0.16 + 0.9) * 0.34 +
      Math.cos(elapsed * 0.24) * 0.12;
    const rotX = 0.34 + Math.sin(elapsed * 0.21) * 0.11 + Math.cos(elapsed * 0.37 + 0.5) * 0.07;
    const angles: MotionAngles = { rotY: rotY, rotX: rotX };
    return angles;
  }

  private rgbForDevice(device: HomeInventoryDevice): string {
    return device.kind === InventoryDeviceKind.Lan ? AppleTheme.LAN_RGB : AppleTheme.PRIMARY_RGB;
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
    elapsed: number, metrics: OrbitDrawMetrics): void {
    const breathe = Math.max(0, 0.45 + 0.55 * Math.sin(elapsed * 1.2));
    const scale = this.layoutScale();
    const hubEdge = metrics.hubEdgeDraw;
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const depth = this.depthFade(item.z);
      const rgb = this.rgbForDevice(item.device);
      const alpha = (0.06 + depth * 0.1) * breathe * item.fade;
      const phase = ripplePhaseOffset(item.device.deviceKey) * Math.PI * 2;
      const pulseRaw = (Math.sin(elapsed * 1.05 + phase) + 1) * 0.5;
      const pulseT = this.smoothStep(pulseRaw);
      const dx = item.sx - cx;
      const dy = item.sy - cy;
      const dist = Math.max(hubEdge, Math.sqrt(dx * dx + dy * dy));
      const ux = dx / dist;
      const uy = dy / dist;
      const linkStartX = cx + ux * hubEdge;
      const linkStartY = cy + uy * hubEdge;
      const ctrlX = linkStartX + (item.sx - linkStartX) * LINK_CTRL_FRAC;
      const ctrlY = linkStartY + (item.sy - linkStartY) * LINK_CTRL_FRAC -
        Math.sin(elapsed * 0.55 + phase) * LINK_CTRL_WOBBLE_VP * scale;
      ctx.beginPath();
      ctx.moveTo(linkStartX, linkStartY);
      ctx.quadraticCurveTo(ctrlX, ctrlY, item.sx, item.sy);
      ctx.strokeStyle = `rgba(${rgb}, ${alpha})`;
      ctx.lineWidth = 1 * scale;
      ctx.stroke();

      const pulse = evalQuadraticBezier(pulseT, linkStartX, linkStartY, ctrlX, ctrlY, item.sx, item.sy);
      ctx.beginPath();
      ctx.arc(pulse.x, pulse.y, 2.5 * scale, 0, Math.PI * 2);
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
    const fillColor = item.device.kind === InventoryDeviceKind.Lan ? AppleTheme.LAN_ACCENT : AppleTheme.PRIMARY;

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

  private collectDeviceDrawItems(rotY: number, rotX: number, cx: number, cy: number,
    elapsed: number, metrics: OrbitDrawMetrics): DeviceDrawItem[] {
    const items: DeviceDrawItem[] = [];
    const hubD = this.hubLayoutDiameter();
    const minOrbitLayout = minOrbitRadiusLayoutVp(hubD, this.canvasLayoutScaleFactor());
    for (let i = 0; i < this.devices.length; i++) {
      const dev = this.devices[i];
      const v = deviceSpherePointForKey(dev.deviceKey);
      const p = this.project(v.x, v.y, v.z, rotY, rotX, cx, cy);
      const phase = ripplePhaseOffset(dev.deviceKey) * Math.PI * 2;
      const wobble = this.layoutScale();
      const rawSx = p.sx + Math.sin(elapsed * 0.85 + phase) * 3 * wobble;
      const rawSy = p.sy + Math.cos(elapsed * 0.62 + phase * 1.2) * 2.2 * wobble;
      const rawLayout = this.drawPointToLayout(rawSx, rawSy, metrics, cx, cy);
      const clampedLayout = clampDeviceOrbitLayout(
        rawLayout.sx,
        rawLayout.sy,
        metrics.cxLayout,
        metrics.cyLayout,
        minOrbitLayout,
        phase
      );
      const drawPos = this.layoutPointToDraw(clampedLayout.x, clampedLayout.y, metrics, cx, cy);
      items.push({
        device: dev,
        sx: drawPos.sx,
        sy: drawPos.sy,
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
    const motion = this.motionAngles(elapsed);
    const rotY = motion.rotY;
    const rotX = motion.rotX;

    ctx.clearRect(0, 0, w, h);

    const orbitMetrics = this.orbitDrawMetrics();
    const deviceItems = this.collectDeviceDrawItems(rotY, rotX, cx, cy, elapsed, orbitMetrics);
    this.lastProjectedDevices = deviceItems;

    if (deviceItems.length > 0) {
      this.drawHubLinks(ctx, deviceItems, cx, cy, elapsed, orbitMetrics);
    }

    for (let i = 0; i < deviceItems.length; i++) {
      const item = deviceItems[i];
      const selected = item.device.deviceKey === this.selectedDeviceKey;
      this.drawDevicePoint(ctx, item, elapsed, selected);
    }

    if (this.devices.length === 0) {
      this.drawRipples(ctx, cx, cy, elapsed, IDLE_HUB_RIPPLE_ID, 1, true, 1, AppleTheme.PRIMARY_RGB);
      this.drawRipples(ctx, cx, cy, elapsed + 0.4, IDLE_HUB_RIPPLE_ID + '_lan', 1, false, 1, AppleTheme.LAN_RGB);
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
        .width(this.hubLayoutDiameter() + 4 * (this.canvasSize / DEFAULT_CANVAS_SIZE))
        .height(this.hubLayoutDiameter() + 4 * (this.canvasSize / DEFAULT_CANVAS_SIZE))
        .fill(AppleTheme.HUB_GLOW)
      Circle()
        .width(this.hubLayoutDiameter())
        .height(this.hubLayoutDiameter())
        .fill(AppleTheme.PRIMARY)
      Column() {
        Text($r('app.string.inventory_hub_near'))
          .fontSize(this.hubLayoutFontSize())
          .fontWeight(FontWeight.Medium)
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
