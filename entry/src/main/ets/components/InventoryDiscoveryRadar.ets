import {
  Blend,
  Camera,
  Color,
  EnvironmentBackgroundType,
  Geometry,
  Light,
  LightType,
  MaterialType,
  Node,
  Quaternion,
  RaycastResult,
  RenderingPipelineType,
  Scene,
  SceneResourceFactory,
  SphereGeometry,
  UnlitMaterial,
  Vec2,
  Vec4
} from '@kit.ArkGraphics3D';
import { AppleTheme } from '../common/AppleTheme';
import {
  deviceSpherePointForKey,
  deviceSpherePointForStableKey,
  ripplePhaseOffset,
  SPHERE_RADIUS
} from '../common/RadarDeviceLayout';
import {
  canvasLayoutScale,
  clampDeviceOrbitLayout,
  minOrbitRadiusLayoutVp
} from '../common/RadarOrbitGeometry';
import {
  AUTO_ROTATE_YAW_SPEED,
  clampOrbitPitch,
  isTapGesture,
  localToNdc,
  orbitEye,
  shouldResumeAutoRotate
} from '../common/SphereCameraMath';
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
  layoutToDraw: number;
  cxLayout: number;
  cyLayout: number;
}

const DEFAULT_CANVAS_SIZE: number = 280;
const FRAME_MS: number = 50;
const HIT_RADIUS: number = 26;
const POINT_RADIUS: number = 0.045;
const SELECTED_POINT_RADIUS: number = 0.06;
const DRAG_RAD_PER_VP: number = 0.006;
const SHELL_NAME: string = 'inventoryShell';
const SHELL_ALPHA: number = 0.16;
const PRIMARY_G: number = 102 / 255;
const PRIMARY_B: number = 204 / 255;
const LAN_G: number = 143 / 255;
const LAN_B: number = 200 / 255;
const RIPPLE_PERIOD: number = 3.2;
const HUB_DIAMETER_BASE: number = 34;
const HUB_FONT_BASE: number = 11;
const IDLE_HUB_RIPPLE_ID: string = '__idle_hub__';

@Component
export struct InventoryDiscoveryRadar {
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @Prop @Watch('onDevicesChanged') devices: HomeInventoryDevice[] = [];
  @Link @Watch('onSelectedChanged') selectedDeviceKey: string;
  @Prop @Watch('onCanvasSizeChanged') canvasSize: number = DEFAULT_CANVAS_SIZE;
  @State sceneReady: boolean = false;
  @State sceneFailed: boolean = false;
  private sceneOpt: SceneOptions | null = null;
  private sceneRef: Scene | null = null;
  private cameraRef: Camera | null = null;
  private factoryRef: SceneResourceFactory | null = null;
  private pointNodes: Map<string, Geometry> = new Map();
  private yaw: number = 0;
  private pitch: number = 0.18;
  private yawSpeed: number = AUTO_ROTATE_YAW_SPEED;
  private dragging: boolean = false;
  private panStartX: number = 0;
  private panStartY: number = 0;
  private panLastX: number = 0;
  private panLastY: number = 0;
  private panLastTs: number = 0;
  private coasting: boolean = false;
  private yawSign: number = 1;
  private sceneBooting: boolean = false;
  private sceneBooted: boolean = false;
  private deviceEpoch: number = 0;
  private pointSyncTail: Promise<void> = Promise.resolve();
  private orbitTimerId: number = -1;
  private lastOrbitMs: number = 0;
  private frameRenderBroken: boolean = false;
  private pickSerial: number = 0;
  private lastPanEndMs: number = 0;
  private bleMat: UnlitMaterial | null = null;
  private lanMat: UnlitMaterial | null = null;
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
    this.bootScene();
    if (this.active && this.canvasReady) {
      this.startTick();
    }
  }

  onCanvasSizeChanged(): void {
    if (this.disposed || !this.active) {
      return;
    }
    if (this.sceneReady && !this.sceneFailed) {
      this.applyCamera();
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
      if (this.sceneReady && !this.sceneFailed) {
        this.startOrbitTick();
      } else {
        this.startTick();
      }
    } else {
      this.stopTick();
      this.stopOrbitTick();
    }
  }

  onSelectedChanged(): void {
    this.refreshPointScales();
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
    this.deviceEpoch++;
    if (this.sceneBooted && !this.sceneFailed) {
      this.enqueuePointSync();
    }
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.canvasReady = false;
    this.sceneReady = false;
    this.stopTick();
    this.stopOrbitTick();
    const scene = this.sceneRef;
    this.sceneRef = null;
    this.cameraRef = null;
    this.factoryRef = null;
    this.pointNodes.clear();
    if (scene != null) {
      scene.destroy();
    }
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
    return {
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
    if (this.sceneReady && !this.sceneFailed) {
      return;
    }
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

  private markSceneFailed(): void {
    this.sceneFailed = true;
    this.sceneReady = false;
    console.error('InventoryDiscoveryRadar 3D scene failed, canvas fallback');
    if (this.active && this.canvasReady && !this.disposed) {
      this.startTick();
    }
  }

  private async bootScene(): Promise<void> {
    if (this.disposed || this.sceneBooting || this.sceneReady || this.sceneFailed) {
      return;
    }
    this.sceneBooting = true;
    try {
      const scene = await Scene.load();
      if (this.disposed) {
        scene.destroy();
        return;
      }
      const factory = scene.getResourceFactory();
      const root = scene.root;
      if (root == null) {
        throw new Error('scene root missing');
      }
      const camera = await factory.createCamera({ name: 'inventoryCam' });
      camera.enabled = true;
      camera.fov = 50 * Math.PI / 180;
      camera.nearPlane = 0.05;
      camera.farPlane = 30;
      camera.renderingPipeline = RenderingPipelineType.FORWARD;
      const clear: Color = { r: 1, g: 1, b: 1, a: 1 };
      camera.clearColor = clear;
      this.attachToRoot(root, camera);

      const light: Light = await factory.createLight({ name: 'key' }, LightType.DIRECTIONAL);
      light.enabled = true;
      const lightColor: Color = { r: 1, g: 1, b: 1, a: 1 };
      light.color = lightColor;
      light.intensity = 6;
      this.attachToRoot(root, light);

      this.clearSceneBackground(scene);
      await this.createShell(factory, root);
      this.bleMat = await this.createUnlit(factory, 'blePointMat', 0, PRIMARY_G, PRIMARY_B, 1, false);
      this.lanMat = await this.createUnlit(factory, 'lanPointMat', 0, LAN_G, LAN_B, 1, false);

      this.factoryRef = factory;
      this.sceneRef = scene;
      this.cameraRef = camera;
      this.applyCamera();
      this.sceneBooted = true;
      this.enqueuePointSync();
      await this.pointSyncTail;
      if (this.disposed) {
        scene.destroy();
        this.sceneRef = null;
        return;
      }
      this.sceneOpt = { scene: scene, modelType: ModelType.SURFACE };
      this.sceneFailed = false;
      this.sceneReady = true;
      this.stopTick();
      console.info('InventoryDiscoveryRadar Component3D scene ready');
      if (this.active) {
        this.startOrbitTick();
      }
    } catch (_err) {
      if (!this.disposed) {
        this.markSceneFailed();
      }
    }
  }

  private clearSceneBackground(scene: Scene): void {
    try {
      scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    } catch (_err) {
    }
  }

  private attachToRoot(root: Node, node: Node): void {
    if (node.parent != null) {
      return;
    }
    root.children.append(node);
  }

  private async createUnlit(factory: SceneResourceFactory, name: string, r: number, g: number, b: number,
    a: number, transparent: boolean): Promise<UnlitMaterial> {
    const created = await factory.createMaterial({ name: name }, MaterialType.UNLIT);
    const mat = created as UnlitMaterial;
    const factor: Vec4 = { x: r, y: g, z: b, w: a };
    mat.baseColor.factor = factor;
    if (transparent) {
      const blendState: Blend = { enabled: true };
      mat.blend = blendState;
      mat.shadowReceiver = false;
    }
    return mat;
  }

  private paintGeometry(geom: Geometry, mat: UnlitMaterial): void {
    geom.mesh.materialOverride = mat;
    const subs = geom.mesh.subMeshes;
    for (let i = 0; i < subs.length; i++) {
      subs[i].material = mat;
    }
  }

  /** 通透外缘：低透明 PRIMARY，不画经线，也不在 3D 路径放中心「近」。 */
  private async createShell(factory: SceneResourceFactory, root: Node): Promise<void> {
    const def = new SphereGeometry();
    def.radius = SPHERE_RADIUS;
    def.segmentCount = 32;
    const mesh = await factory.createMesh({ name: 'inventoryShellMesh' }, def);
    const geom = await factory.createGeometry({ name: SHELL_NAME }, mesh);
    geom.name = SHELL_NAME;
    const mat = await this.createUnlit(factory, 'inventoryShellMat', 0, PRIMARY_G, PRIMARY_B, SHELL_ALPHA, true);
    this.paintGeometry(geom, mat);
    this.attachToRoot(root, geom);
  }

  private enqueuePointSync(): void {
    this.pointSyncTail = this.pointSyncTail
      .then((): Promise<void> => {
        return this.syncPointNodes();
      })
      .catch((): Promise<void> => {
        console.error('InventoryDiscoveryRadar point sync failed');
        return Promise.resolve();
      });
  }

  private async syncPointNodes(): Promise<void> {
    let pass = 0;
    while (pass < 4) {
      pass++;
      const epoch = this.deviceEpoch;
      await this.syncPointNodesOnce();
      if (epoch === this.deviceEpoch) {
        return;
      }
    }
  }

  private async syncPointNodesOnce(): Promise<void> {
    const factory = this.factoryRef;
    const scene = this.sceneRef;
    if (factory == null || scene == null || scene.root == null || this.sceneFailed || this.disposed) {
      return;
    }
    const root = scene.root;
    const alive: Set<string> = new Set();
    for (let i = 0; i < this.devices.length; i++) {
      const key = this.devices[i].deviceKey;
      if (key.length > 0) {
        alive.add(key);
      }
    }
    const stale: string[] = [];
    this.pointNodes.forEach((_geom: Geometry, key: string) => {
      if (!alive.has(key)) {
        stale.push(key);
      }
    });
    for (let i = 0; i < stale.length; i++) {
      const key = stale[i];
      const node = this.pointNodes.get(key);
      if (node != null) {
        this.dropNode(node);
      }
      this.pointNodes.delete(key);
    }
    for (let i = 0; i < this.devices.length; i++) {
      const dev = this.devices[i];
      if (dev.deviceKey.length === 0) {
        continue;
      }
      const existing = this.pointNodes.get(dev.deviceKey);
      if (existing != null) {
        existing.visible = true;
        existing.name = dev.deviceKey;
        this.applyPointScale(existing, dev.deviceKey);
        continue;
      }
      await this.createPoint(factory, root, dev);
    }
  }

  private async createPoint(factory: SceneResourceFactory, root: Node, device: HomeInventoryDevice): Promise<void> {
    const def = new SphereGeometry();
    def.radius = POINT_RADIUS;
    def.segmentCount = 16;
    const mesh = await factory.createMesh({ name: `pointMesh:${device.deviceKey}` }, def);
    const geom = await factory.createGeometry({ name: device.deviceKey }, mesh);
    geom.name = device.deviceKey;
    const p = deviceSpherePointForStableKey(device.deviceKey);
    geom.position = { x: p.x, y: p.y, z: p.z };
    const mat = device.kind === InventoryDeviceKind.Lan ? this.lanMat : this.bleMat;
    if (mat != null) {
      this.paintGeometry(geom, mat);
    }
    this.applyPointScale(geom, device.deviceKey);
    geom.visible = true;
    this.attachToRoot(root, geom);
    this.pointNodes.set(device.deviceKey, geom);
  }

  private applyPointScale(node: Geometry, deviceKey: string): void {
    const selected = deviceKey.length > 0 && deviceKey === this.selectedDeviceKey;
    const s = selected ? (SELECTED_POINT_RADIUS / POINT_RADIUS) : 1;
    node.scale = { x: s, y: s, z: s };
  }

  private refreshPointScales(): void {
    this.pointNodes.forEach((geom: Geometry, key: string) => {
      this.applyPointScale(geom, key);
    });
  }

  private dropNode(node: Geometry): void {
    try {
      node.visible = false;
      const parent = node.parent;
      if (parent != null) {
        parent.children.remove(node);
      }
      node.destroy();
    } catch (_err) {
    }
  }

  private applyCamera(): void {
    const camera = this.cameraRef;
    if (camera == null) {
      return;
    }
    const eye = orbitEye(this.yaw, this.pitch);
    camera.position = { x: eye.x, y: eye.y, z: eye.z };
    camera.rotation = this.lookAtOriginQuaternion(eye.x, eye.y, eye.z);
  }

  /** 相机默认朝 -Z，用从眼睛指向原点的正交基求 look-at，避免欧拉连乘。 */
  private lookAtOriginQuaternion(ex: number, ey: number, ez: number): Quaternion {
    const len = Math.sqrt(ex * ex + ey * ey + ez * ez);
    if (len < 1e-6) {
      const identity: Quaternion = { x: 0, y: 0, z: 0, w: 1 };
      return identity;
    }
    const zx = ex / len;
    const zy = ey / len;
    const zz = ez / len;
    let xx = zz;
    let xy = 0;
    let xz = -zx;
    const xl = Math.sqrt(xx * xx + xy * xy + xz * xz);
    if (xl < 1e-6) {
      const identity: Quaternion = { x: 0, y: 0, z: 0, w: 1 };
      return identity;
    }
    xx = xx / xl;
    xy = xy / xl;
    xz = xz / xl;
    const yx = zy * xz - zz * xy;
    const yy = zz * xx - zx * xz;
    const yz = zx * xy - zy * xx;
    return this.quaternionFromBasis(xx, xy, xz, yx, yy, yz, zx, zy, zz);
  }

  private quaternionFromBasis(xx: number, xy: number, xz: number, yx: number, yy: number, yz: number,
    zx: number, zy: number, zz: number): Quaternion {
    const trace = xx + yy + zz;
    let qx = 0;
    let qy = 0;
    let qz = 0;
    let qw = 1;
    if (trace > 0) {
      const s = Math.sqrt(trace + 1) * 2;
      qw = 0.25 * s;
      qx = (yz - zy) / s;
      qy = (zx - xz) / s;
      qz = (xy - yx) / s;
    } else if (xx > yy && xx > zz) {
      const s = Math.sqrt(1 + xx - yy - zz) * 2;
      qw = (yz - zy) / s;
      qx = 0.25 * s;
      qy = (yx + xy) / s;
      qz = (zx + xz) / s;
    } else if (yy > zz) {
      const s = Math.sqrt(1 + yy - xx - zz) * 2;
      qw = (zx - xz) / s;
      qx = (yx + xy) / s;
      qy = 0.25 * s;
      qz = (zy + yz) / s;
    } else {
      const s = Math.sqrt(1 + zz - xx - yy) * 2;
      qw = (xy - yx) / s;
      qx = (zx + xz) / s;
      qy = (zy + yz) / s;
      qz = 0.25 * s;
    }
    const q: Quaternion = { x: qx, y: qy, z: qz, w: qw };
    return q;
  }

  private startOrbitTick(): void {
    if (!this.sceneReady || !this.active || this.disposed || this.sceneFailed || this.orbitTimerId >= 0) {
      return;
    }
    this.lastOrbitMs = Date.now();
    this.orbitTimerId = setInterval(() => {
      this.onOrbitTick();
    }, FRAME_MS) as number;
  }

  private stopOrbitTick(): void {
    if (this.orbitTimerId >= 0) {
      clearInterval(this.orbitTimerId);
      this.orbitTimerId = -1;
    }
  }

  private onOrbitTick(): void {
    if (this.disposed || !this.active || !this.sceneReady || this.sceneFailed) {
      return;
    }
    const now = Date.now();
    let dt = (now - this.lastOrbitMs) / 1000;
    this.lastOrbitMs = now;
    if (dt < 0) {
      dt = 0;
    } else if (dt > 0.1) {
      dt = 0.1;
    }
    if (this.coasting) {
      this.yaw += this.yawSpeed * dt;
      this.yawSpeed = this.yawSpeed * 0.92;
      if (shouldResumeAutoRotate(this.yawSpeed)) {
        const sign = this.yawSign < 0 ? -1 : 1;
        this.yawSpeed = sign * AUTO_ROTATE_YAW_SPEED;
        this.coasting = false;
        this.dragging = false;
      }
    } else if (!this.dragging) {
      this.yaw += this.yawSpeed * dt;
    }
    this.applyCamera();
    this.renderOrbitFrame();
  }

  private renderOrbitFrame(): void {
    const scene = this.sceneRef;
    if (scene == null || this.frameRenderBroken) {
      return;
    }
    try {
      scene.renderFrame({ alwaysRender: true });
    } catch (_err) {
      this.frameRenderBroken = true;
    }
  }

  private fingerLocalX(event: GestureEvent): number {
    const fingers = event.fingerList;
    if (fingers != null && fingers.length > 0) {
      return fingers[0].localX;
    }
    return this.canvasSize / 2;
  }

  private fingerLocalY(event: GestureEvent): number {
    const fingers = event.fingerList;
    if (fingers != null && fingers.length > 0) {
      return fingers[0].localY;
    }
    return this.canvasSize / 2;
  }

  private noteYawSign(speed: number): void {
    if (speed > 0.0001) {
      this.yawSign = 1;
    } else if (speed < -0.0001) {
      this.yawSign = -1;
    }
  }

  private onSpherePanStart(event: GestureEvent): void {
    this.dragging = true;
    this.coasting = false;
    this.panStartX = this.fingerLocalX(event);
    this.panStartY = this.fingerLocalY(event);
    this.panLastX = event.offsetX;
    this.panLastY = event.offsetY;
    this.panLastTs = Date.now();
  }

  private onSpherePanUpdate(event: GestureEvent): void {
    const now = Date.now();
    const dx = event.offsetX - this.panLastX;
    const dy = event.offsetY - this.panLastY;
    const prevYaw = this.yaw;
    this.yaw -= dx * DRAG_RAD_PER_VP;
    this.pitch = clampOrbitPitch(this.pitch - dy * DRAG_RAD_PER_VP);
    const dt = (now - this.panLastTs) / 1000;
    if (dt > 0.001) {
      this.yawSpeed = (this.yaw - prevYaw) / dt;
      this.noteYawSign(this.yawSpeed);
    }
    this.panLastX = event.offsetX;
    this.panLastY = event.offsetY;
    this.panLastTs = now;
    this.applyCamera();
  }

  private onSpherePanEnd(event: GestureEvent): void {
    this.lastPanEndMs = Date.now();
    if (isTapGesture(event.offsetX, event.offsetY)) {
      this.dragging = false;
      this.coasting = false;
      const sign = this.yawSign < 0 ? -1 : 1;
      this.yawSpeed = sign * AUTO_ROTATE_YAW_SPEED;
      this.pickAt(this.panStartX, this.panStartY);
      return;
    }
    const flick = -event.velocityX * DRAG_RAD_PER_VP;
    if (Math.abs(flick) > Math.abs(this.yawSpeed)) {
      this.yawSpeed = flick;
    }
    this.noteYawSign(this.yawSpeed);
    this.coasting = true;
    this.dragging = true;
  }

  private onSphereClick(event: ClickEvent): void {
    if (Date.now() - this.lastPanEndMs < 400) {
      return;
    }
    this.pickAt(event.x, event.y);
  }

  private deviceKeyFromHit(node: Node): string {
    let current: Node | null = node;
    let depth = 0;
    while (current != null && depth < 4) {
      if (this.pointNodes.has(current.name)) {
        return current.name;
      }
      if (current.name === SHELL_NAME) {
        return '';
      }
      current = current.parent;
      depth++;
    }
    return '';
  }

  private async pickAt(x: number, y: number): Promise<void> {
    const camera = this.cameraRef;
    const scene = this.sceneRef;
    if (camera == null || scene == null || scene.root == null || this.sceneFailed) {
      return;
    }
    const serial = this.pickSerial + 1;
    this.pickSerial = serial;
    const ndc = localToNdc(x, y, this.canvasSize, this.canvasSize);
    const view: Vec2 = { x: ndc.x, y: ndc.y };
    let hits: RaycastResult[] = [];
    try {
      hits = await camera.raycast(view, { rootNode: scene.root });
    } catch (_err) {
      console.error('InventoryDiscoveryRadar raycast failed');
      return;
    }
    if (serial !== this.pickSerial || this.disposed) {
      return;
    }
    for (let i = 0; i < hits.length; i++) {
      const key = this.deviceKeyFromHit(hits[i].node);
      if (key.length > 0) {
        this.selectedDeviceKey = key;
        return;
      }
    }
  }

  private sceneOptions(): SceneOptions {
    if (this.sceneOpt != null) {
      return this.sceneOpt;
    }
    const empty: SceneOptions = { modelType: ModelType.SURFACE };
    return empty;
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

  @Builder
  sphereBranch() {
    Stack({ alignContent: Alignment.Center }) {
      Component3D(this.sceneOptions())
        .width(this.canvasSize)
        .height(this.canvasSize)
    }
    .width(this.canvasSize)
    .height(this.canvasSize)
    .hitTestBehavior(HitTestMode.Default)
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
        .onActionStart((event: GestureEvent) => {
          this.onSpherePanStart(event);
        })
        .onActionUpdate((event: GestureEvent) => {
          this.onSpherePanUpdate(event);
        })
        .onActionEnd((event: GestureEvent) => {
          this.onSpherePanEnd(event);
        })
    )
    .onClick((event: ClickEvent) => {
      this.onSphereClick(event);
    })
  }

  @Builder
  canvasBranch() {
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

  build() {
    if (this.sceneReady && this.sceneOpt != null && !this.sceneFailed) {
      this.sphereBranch()
    } else {
      this.canvasBranch()
    }
  }
}
