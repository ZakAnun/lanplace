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
  RenderingPipelineType,
  Scene,
  SceneResourceFactory,
  SphereGeometry,
  UnlitMaterial,
  Vec4
} from '@kit.ArkGraphics3D';
import { AppleTheme } from '../common/AppleTheme';
import {
  deviceSpherePointForStableKey,
  goldenSpherePoint,
  ripplePhaseOffset,
  SPHERE_RADIUS,
  Vec3
} from '../common/RadarDeviceLayout';
import {
  canvasLayoutScale
} from '../common/RadarOrbitGeometry';
import {
  applyOrbitPan,
  AUTO_ROTATE_YAW_SPEED,
  CAMERA_FOV_RAD,
  clampOrbitPitch,
  clampOrbitSpeed,
  decayOrbitSpeed,
  firstFingerLocalX,
  firstFingerLocalY,
  isTapGesture,
  orbitEye,
  orbitSensitivity,
  pickNearestFrontKey,
  pointFacingAlpha,
  pointFacingScale,
  SELECTED_POINT_SCALE_BOOST,
  shouldResumeAutoRotate,
  sphereFacing,
  TAP_SLOP_VP,
  worldToCanvas
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

const DEFAULT_CANVAS_SIZE: number = 280;
const FRAME_MS: number = 50;
const HIT_RADIUS: number = 26;
const POINT_RADIUS: number = 0.045;
const FIELD_POINT_RADIUS: number = 0.016;
const FIELD_COUNT: number = 96;
const FIELD_PREFIX: string = 'fieldDot:';
const PRIMARY_G: number = 102 / 255;
const PRIMARY_B: number = 204 / 255;
const LAN_G: number = 143 / 255;
const LAN_B: number = 200 / 255;
const RIPPLE_PERIOD: number = 3.2;

@Component
export struct InventoryDiscoveryRadar {
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @Prop @Watch('onDevicesChanged') devices: HomeInventoryDevice[] = [];
  @Link @Watch('onSelectedChanged') selectedDeviceKey: string;
  @Prop @Watch('onCanvasSizeChanged') canvasSize: number = DEFAULT_CANVAS_SIZE;
  @State sceneReady: boolean = false;
  @State sceneFailed: boolean = false;
  @State selectedRingX: number = 0;
  @State selectedRingY: number = 0;
  @State selectedRingSize: number = 18;
  @State selectedRingVisible: boolean = false;
  private sceneOpt: SceneOptions | null = null;
  private sceneRef: Scene | null = null;
  private cameraRef: Camera | null = null;
  private factoryRef: SceneResourceFactory | null = null;
  private pointNodes: Map<string, Geometry> = new Map();
  private yaw: number = 0;
  private pitch: number = 0.18;
  private yawSpeed: number = AUTO_ROTATE_YAW_SPEED;
  private pitchSpeed: number = 0;
  private dragging: boolean = false;
  private panStartX: number = 0;
  private panStartY: number = 0;
  private panLastX: number = 0;
  private panLastY: number = 0;
  private panLastTs: number = 0;
  private panBeyondSlop: boolean = false;
  /** 点击拾取完成前冻结自转，射线对着按下时的相机。 */
  private pickOrbitHold: boolean = false;
  private coasting: boolean = false;
  private yawSign: number = 1;
  private sceneBooting: boolean = false;
  private sceneBooted: boolean = false;
  private deviceEpoch: number = 0;
  private pointSyncTail: Promise<void> = Promise.resolve();
  private orbitTimerId: number = -1;
  private lastOrbitMs: number = 0;
  private frameRenderBroken: boolean = false;
  private lastPanEndMs: number = 0;
  private pointMats: Map<string, UnlitMaterial> = new Map();
  private pointKinds: Map<string, InventoryDeviceKind> = new Map();
  private fieldNodes: Geometry[] = [];
  private fieldMats: UnlitMaterial[] = [];
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
      this.refreshPointAppearances();
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
    this.refreshPointAppearances();
    this.renderOrbitFrame();
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
    this.pointMats.clear();
    this.pointKinds.clear();
    this.fieldNodes = [];
    this.fieldMats = [];
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

  private layoutToDrawScale(): number {
    const layout = Math.max(this.canvasSize, 1);
    const draw = this.drawWidth > 0 ? this.drawWidth : layout;
    return draw / layout;
  }

  private canvasLayoutScaleFactor(): number {
    return canvasLayoutScale(this.canvasSize, DEFAULT_CANVAS_SIZE);
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
    this.lastOrbitMs = Date.now();
    this.drawFrame();
    this.tickTimerId = setInterval(() => {
      if (this.disposed || !this.active) {
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
      this.stepOrbit(dt);
      this.drawFrame();
    }, FRAME_MS) as number;
  }

  private facingDepth(facing: number): number {
    let t = (facing + 1) * 0.5;
    if (t < 0) {
      t = 0;
    } else if (t > 1) {
      t = 1;
    }
    return t;
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
    const depth = this.facingDepth(item.z);
    const fade = item.fade * depth;
    const sx = item.sx;
    const sy = item.sy;
    const scale = this.layoutScale();
    const coreR = (selected ? 7.5 : 6) * scale * (0.38 + 0.74 * depth);
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
      ctx.arc(sx, sy, coreR + 5 * scale, 0, Math.PI * 2);
      ctx.strokeStyle = AppleTheme.PRIMARY;
      ctx.lineWidth = 1.5;
      ctx.globalAlpha = 0.9;
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
  }

  private collectDeviceDrawItems(cx: number, cy: number): DeviceDrawItem[] {
    const items: DeviceDrawItem[] = [];
    const eye = orbitEye(this.yaw, this.pitch);
    const layout = Math.max(this.canvasSize, 1);
    const toDraw = this.layoutToDrawScale();
    for (let i = 0; i < this.devices.length; i++) {
      const dev = this.devices[i];
      const v = deviceSpherePointForStableKey(dev.deviceKey);
      const facing = sphereFacing(v, eye);
      const proj = worldToCanvas(v, eye, CAMERA_FOV_RAD, layout);
      if (proj.z >= 0) {
        continue;
      }
      items.push({
        device: dev,
        sx: cx + (proj.x - layout * 0.5) * toDraw,
        sy: cy + (proj.y - layout * 0.5) * toDraw,
        z: facing,
        fade: this.fadeInForDevice(dev.deviceKey)
      });
    }
    items.sort((a, b) => a.z - b.z);
    return items;
  }

  private collectFieldDrawItems(cx: number, cy: number): ProjectedPoint[] {
    const items: ProjectedPoint[] = [];
    const eye = orbitEye(this.yaw, this.pitch);
    const layout = Math.max(this.canvasSize, 1);
    const toDraw = this.layoutToDrawScale();
    for (let i = 0; i < FIELD_COUNT; i++) {
      const v = goldenSpherePoint(i, FIELD_COUNT, SPHERE_RADIUS);
      const facing = sphereFacing(v, eye);
      const proj = worldToCanvas(v, eye, CAMERA_FOV_RAD, layout);
      if (proj.z >= 0) {
        continue;
      }
      items.push({
        sx: cx + (proj.x - layout * 0.5) * toDraw,
        sy: cy + (proj.y - layout * 0.5) * toDraw,
        z: facing
      });
    }
    items.sort((a, b) => a.z - b.z);
    return items;
  }

  private drawFieldPoint(ctx: CanvasRenderingContext2D, item: ProjectedPoint): void {
    const depth = this.facingDepth(item.z);
    const scale = this.layoutScale();
    const r = 1.7 * scale * (0.38 + 0.62 * depth);
    const alpha = 0.1 + 0.28 * depth;
    ctx.beginPath();
    ctx.arc(item.sx, item.sy, r, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(${AppleTheme.PRIMARY_RGB}, ${alpha})`;
    ctx.fill();
  }

  private drawFrame(): void {
    this.syncCanvasMetrics();
    const ctx = this.ctx;
    const w = this.drawWidth;
    const h = this.drawHeight;
    const cx = this.centerDrawX();
    const cy = this.centerDrawY();
    const elapsed = (Date.now() - this.startMs) / 1000;

    ctx.clearRect(0, 0, w, h);

    const fieldItems = this.collectFieldDrawItems(cx, cy);
    for (let i = 0; i < fieldItems.length; i++) {
      this.drawFieldPoint(ctx, fieldItems[i]);
    }

    const deviceItems = this.collectDeviceDrawItems(cx, cy);

    for (let i = 0; i < deviceItems.length; i++) {
      const item = deviceItems[i];
      const selected = item.device.deviceKey === this.selectedDeviceKey;
      this.drawDevicePoint(ctx, item, elapsed, selected);
    }
  }

  private handleTapAt(x: number, y: number): void {
    const key = this.pickFrontDeviceAt(x, y);
    if (key.length > 0) {
      this.selectedDeviceKey = key;
    }
  }

  private pickFrontDeviceAt(x: number, y: number): string {
    const keys: string[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      keys.push(this.devices[i].deviceKey);
    }
    return pickNearestFrontKey(keys, x, y, this.yaw, this.pitch, this.canvasSize, HIT_RADIUS);
  }

  private markSceneFailed(): void {
    this.sceneFailed = true;
    this.sceneReady = false;
    console.error('InventoryDiscoveryRadar 3D scene failed, canvas fallback');
    if (this.active && this.canvasReady && !this.disposed) {
      this.startTick();
    }
  }

  private releaseBootScene(scene: Scene | null): void {
    const held = this.sceneRef;
    this.sceneRef = null;
    this.cameraRef = null;
    this.factoryRef = null;
    this.sceneOpt = null;
    this.sceneReady = false;
    this.sceneBooted = false;
    this.pointNodes.clear();
    this.pointMats.clear();
    this.pointKinds.clear();
    this.fieldNodes = [];
    this.fieldMats = [];
    this.selectedRingVisible = false;
    const target: Scene | null = held != null ? held : scene;
    if (target != null) {
      try {
        target.destroy();
      } catch (_err) {
      }
    }
  }

  private async bootScene(): Promise<void> {
    if (this.disposed || this.sceneBooting || this.sceneReady || this.sceneFailed) {
      return;
    }
    this.sceneBooting = true;
    let scene: Scene | null = null;
    try {
      scene = await Scene.load();
      if (scene == null) {
        throw new Error('scene load missing');
      }
      if (this.disposed) {
        this.releaseBootScene(scene);
        return;
      }
      const factory = scene.getResourceFactory();
      const root = scene.root;
      if (root == null) {
        throw new Error('scene root missing');
      }
      const camera = await factory.createCamera({ name: 'inventoryCam' });
      camera.enabled = true;
      camera.fov = CAMERA_FOV_RAD;
      camera.nearPlane = 0.05;
      camera.farPlane = 30;
      camera.renderingPipeline = RenderingPipelineType.FORWARD;
      const clear: Color = { r: 0, g: 0, b: 0, a: 0 };
      camera.clearColor = clear;
      this.attachToRoot(root, camera);

      const light: Light = await factory.createLight({ name: 'key' }, LightType.DIRECTIONAL);
      light.enabled = true;
      const lightColor: Color = { r: 1, g: 1, b: 1, a: 1 };
      light.color = lightColor;
      light.intensity = 6;
      this.attachToRoot(root, light);

      this.clearSceneBackground(scene);

      this.factoryRef = factory;
      this.sceneRef = scene;
      this.cameraRef = camera;
      this.applyCamera();
      await this.createFieldCloud(factory, root);
      if (this.disposed) {
        this.releaseBootScene(scene);
        return;
      }
      this.sceneBooted = true;
      this.enqueuePointSync();
      await this.pointSyncTail;
      if (this.disposed) {
        this.releaseBootScene(scene);
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
      this.releaseBootScene(scene);
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
        this.dropNode(node, key);
      }
      this.pointNodes.delete(key);
      this.pointMats.delete(key);
      this.pointKinds.delete(key);
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
        this.pointKinds.set(dev.deviceKey, dev.kind);
        this.applyPointAppearance(existing, dev.deviceKey);
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
    const isLan = device.kind === InventoryDeviceKind.Lan;
    const mat = await this.createUnlit(
      factory,
      `pointMat:${device.deviceKey}`,
      0,
      isLan ? LAN_G : PRIMARY_G,
      isLan ? LAN_B : PRIMARY_B,
      1,
      true
    );
    this.paintGeometry(geom, mat);
    this.pointMats.set(device.deviceKey, mat);
    this.pointKinds.set(device.deviceKey, device.kind);
    this.applyPointAppearance(geom, device.deviceKey);
    geom.visible = true;
    this.attachToRoot(root, geom);
    this.pointNodes.set(device.deviceKey, geom);
  }

  private applyPointAppearance(node: Geometry, deviceKey: string): void {
    const pos = deviceSpherePointForStableKey(deviceKey);
    const facing = sphereFacing(pos, orbitEye(this.yaw, this.pitch));
    const selected = deviceKey.length > 0 && deviceKey === this.selectedDeviceKey;
    let s = pointFacingScale(facing);
    if (selected) {
      s = s * SELECTED_POINT_SCALE_BOOST;
    }
    node.scale = { x: s, y: s, z: s };
    const mat = this.pointMats.get(deviceKey);
    if (mat == null) {
      return;
    }
    const kind = this.pointKinds.get(deviceKey);
    const isLan = kind === InventoryDeviceKind.Lan;
    let t = (facing + 1) * 0.5;
    if (t < 0) {
      t = 0;
    } else if (t > 1) {
      t = 1;
    }
    const dim = 0.32 + 0.68 * t;
    let a = pointFacingAlpha(facing);
    if (selected) {
      a = Math.max(a, 0.82);
    }
    const factor: Vec4 = {
      x: isLan ? 0 : 0,
      y: (isLan ? LAN_G : PRIMARY_G) * dim,
      z: (isLan ? LAN_B : PRIMARY_B) * dim,
      w: a
    };
    mat.baseColor.factor = factor;
  }

  private refreshPointAppearances(): void {
    this.pointNodes.forEach((geom: Geometry, key: string) => {
      this.applyPointAppearance(geom, key);
    });
    this.refreshFieldAppearances();
    this.updateSelectedRing();
  }

  private async createFieldCloud(factory: SceneResourceFactory, root: Node): Promise<void> {
    for (let i = 0; i < FIELD_COUNT; i++) {
      if (this.disposed) {
        return;
      }
      await this.createFieldDot(factory, root, i);
    }
    this.refreshFieldAppearances();
  }

  private async createFieldDot(factory: SceneResourceFactory, root: Node, index: number): Promise<void> {
    const def = new SphereGeometry();
    def.radius = FIELD_POINT_RADIUS;
    def.segmentCount = 8;
    const mesh = await factory.createMesh({ name: `fieldMesh:${index}` }, def);
    const geom = await factory.createGeometry({ name: `${FIELD_PREFIX}${index}` }, mesh);
    geom.name = `${FIELD_PREFIX}${index}`;
    const p = goldenSpherePoint(index, FIELD_COUNT, SPHERE_RADIUS);
    geom.position = { x: p.x, y: p.y, z: p.z };
    const mat = await this.createUnlit(
      factory,
      `fieldMat:${index}`,
      0,
      PRIMARY_G,
      PRIMARY_B,
      0.3,
      true
    );
    this.paintGeometry(geom, mat);
    this.applyFieldAppearance(geom, mat, p);
    geom.visible = true;
    this.attachToRoot(root, geom);
    this.fieldNodes.push(geom);
    this.fieldMats.push(mat);
  }

  private applyFieldAppearance(node: Geometry, mat: UnlitMaterial, pos: Vec3): void {
    const facing = sphereFacing(pos, orbitEye(this.yaw, this.pitch));
    const s = pointFacingScale(facing) * 0.55;
    node.scale = { x: s, y: s, z: s };
    let t = (facing + 1) * 0.5;
    if (t < 0) {
      t = 0;
    } else if (t > 1) {
      t = 1;
    }
    const dim = 0.28 + 0.55 * t;
    const a = pointFacingAlpha(facing) * 0.42;
    const factor: Vec4 = {
      x: 0,
      y: PRIMARY_G * dim,
      z: PRIMARY_B * dim,
      w: a
    };
    mat.baseColor.factor = factor;
  }

  private refreshFieldAppearances(): void {
    const n = this.fieldNodes.length;
    for (let i = 0; i < n; i++) {
      const geom = this.fieldNodes[i];
      const mat = this.fieldMats[i];
      if (geom == null || mat == null) {
        continue;
      }
      const p = goldenSpherePoint(i, FIELD_COUNT, SPHERE_RADIUS);
      this.applyFieldAppearance(geom, mat, p);
    }
  }

  private updateSelectedRing(): void {
    const key = this.selectedDeviceKey;
    if (key.length === 0 || !this.pointNodes.has(key) || this.canvasSize <= 0) {
      this.selectedRingVisible = false;
      return;
    }
    const p = deviceSpherePointForStableKey(key);
    const eye = orbitEye(this.yaw, this.pitch);
    const facing = sphereFacing(p, eye);
    const proj = worldToCanvas(p, eye, CAMERA_FOV_RAD, this.canvasSize);
    if (proj.z >= 0 || facing <= 0) {
      this.selectedRingVisible = false;
      return;
    }
    const size = 14 + 16 * pointFacingScale(facing);
    this.selectedRingX = proj.x;
    this.selectedRingY = proj.y;
    this.selectedRingSize = size;
    this.selectedRingVisible = true;
  }

  private dropNode(node: Geometry, deviceKey: string): void {
    try {
      node.visible = false;
      const parent = node.parent;
      if (parent != null) {
        parent.children.remove(node);
      }
      node.destroy();
    } catch (_err) {
    }
    const mat = this.pointMats.get(deviceKey);
    if (mat != null) {
      try {
        mat.destroy();
      } catch (_err) {
      }
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
    this.stepOrbit(dt);
    this.applyCamera();
    this.refreshPointAppearances();
    this.renderOrbitFrame();
  }

  private stepOrbit(dt: number): void {
    if (this.coasting) {
      this.yaw += this.yawSpeed * dt;
      this.pitch = clampOrbitPitch(this.pitch + this.pitchSpeed * dt);
      this.yawSpeed = decayOrbitSpeed(this.yawSpeed, dt);
      this.pitchSpeed = decayOrbitSpeed(this.pitchSpeed, dt);
      if (shouldResumeAutoRotate(this.yawSpeed) && shouldResumeAutoRotate(this.pitchSpeed)) {
        const sign = this.yawSign < 0 ? -1 : 1;
        this.yawSpeed = sign * AUTO_ROTATE_YAW_SPEED;
        this.pitchSpeed = 0;
        this.coasting = false;
        this.dragging = false;
      }
    } else if (!this.dragging && !this.pickOrbitHold) {
      this.yaw += this.yawSpeed * dt;
    }
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
    return firstFingerLocalX(event.fingerList, this.canvasSize / 2);
  }

  private fingerLocalY(event: GestureEvent): number {
    return firstFingerLocalY(event.fingerList, this.canvasSize / 2);
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
    this.panBeyondSlop = false;
    this.panStartX = this.fingerLocalX(event);
    this.panStartY = this.fingerLocalY(event);
    this.panLastX = event.offsetX;
    this.panLastY = event.offsetY;
    this.panLastTs = Date.now();
  }

  /** 累计位移未超过 TAP_SLOP_VP 时不改轨道；越过后只吃超出的那一段。 */
  private onSpherePanUpdate(event: GestureEvent): void {
    const now = Date.now();
    if (!this.panBeyondSlop) {
      if (isTapGesture(event.offsetX, event.offsetY)) {
        return;
      }
      this.panBeyondSlop = true;
      const dist = Math.sqrt(event.offsetX * event.offsetX + event.offsetY * event.offsetY);
      const excess = dist - TAP_SLOP_VP;
      if (excess > 0 && dist > 0.0001) {
        const scale = excess / dist;
        this.applyPanDelta(event.offsetX * scale, event.offsetY * scale, now);
      }
      this.panLastX = event.offsetX;
      this.panLastY = event.offsetY;
      this.panLastTs = now;
      return;
    }
    const dx = event.offsetX - this.panLastX;
    const dy = event.offsetY - this.panLastY;
    this.applyPanDelta(dx, dy, now);
    this.panLastX = event.offsetX;
    this.panLastY = event.offsetY;
    this.panLastTs = now;
  }

  private applyPanDelta(dx: number, dy: number, now: number): void {
    const prevYaw = this.yaw;
    const prevPitch = this.pitch;
    const next = applyOrbitPan(this.yaw, this.pitch, dx, dy, orbitSensitivity(this.canvasSize));
    this.yaw = next.x;
    this.pitch = next.y;
    const dt = (now - this.panLastTs) / 1000;
    if (dt > 0.001) {
      this.yawSpeed = clampOrbitSpeed((this.yaw - prevYaw) / dt);
      this.pitchSpeed = clampOrbitSpeed((this.pitch - prevPitch) / dt);
      this.noteYawSign(this.yawSpeed);
    }
    this.applyCamera();
    this.refreshPointAppearances();
    this.renderOrbitFrame();
    if (!this.sceneReady || this.sceneFailed) {
      this.drawFrame();
    }
  }

  private onSpherePanEnd(event: GestureEvent): void {
    this.lastPanEndMs = Date.now();
    if (!this.panBeyondSlop && isTapGesture(event.offsetX, event.offsetY)) {
      this.pickOrbitHold = true;
      this.dragging = false;
      this.coasting = false;
      this.panBeyondSlop = false;
      const sign = this.yawSign < 0 ? -1 : 1;
      this.yawSpeed = sign * AUTO_ROTATE_YAW_SPEED;
      this.handleTapAt(this.panStartX, this.panStartY);
      this.pickOrbitHold = false;
      return;
    }
    this.panBeyondSlop = false;
    const k = orbitSensitivity(this.canvasSize);
    this.yawSpeed = clampOrbitSpeed(-event.velocityX * k);
    this.pitchSpeed = clampOrbitSpeed(event.velocityY * k);
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

  private pickAt(x: number, y: number): void {
    this.pickOrbitHold = false;
    this.handleTapAt(x, y);
  }

  private sceneOptions(): SceneOptions {
    if (this.sceneOpt != null) {
      return this.sceneOpt;
    }
    const empty: SceneOptions = { modelType: ModelType.SURFACE };
    return empty;
  }

  /**
   * SDK createShader 只接受资源 URI，没有内联 fresnel 源码接口。
   * 用屏幕空间描边环代替实心球壳，中心不产生球面片元。
   */
  @Builder
  selectedPointRing() {
    if (this.selectedRingVisible) {
      Circle()
        .width(this.selectedRingSize)
        .height(this.selectedRingSize)
        .fill('#00000000')
        .stroke(AppleTheme.PRIMARY)
        .strokeWidth(1.5)
        .opacity(0.9)
        .position({
          x: this.selectedRingX - this.selectedRingSize / 2,
          y: this.selectedRingY - this.selectedRingSize / 2
        })
        .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  sphereBranch() {
    Stack({ alignContent: Alignment.Center }) {
      Component3D(this.sceneOptions())
        .width(this.canvasSize)
        .height(this.canvasSize)
        .backgroundColor('#00000000')
      this.selectedPointRing()
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
        .hitTestBehavior(HitTestMode.None)
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

    }
    .width(this.canvasSize)
    .height(this.canvasSize)
    .alignContent(Alignment.Center)
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
      if (Date.now() - this.lastPanEndMs < 400) {
        return;
      }
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
