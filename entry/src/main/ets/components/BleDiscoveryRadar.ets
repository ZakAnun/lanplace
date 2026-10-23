import { AppleTheme } from '../common/AppleTheme';

interface Vec3 {
  x: number;
  y: number;
  z: number;
}

interface ProjectedPoint {
  sx: number;
  sy: number;
  z: number;
}

const CANVAS_SIZE: number = 280;
const PARTICLE_COUNT: number = 36;
const SPHERE_RADIUS: number = 1;
const FRAME_MS: number = 33;

@Component
export struct BleDiscoveryRadar {
  @Prop active: boolean = true;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private tickTimerId: number = -1;
  private particles: Vec3[] = [];
  private startMs: number = 0;
  private disposed: boolean = false;

  aboutToAppear(): void {
    this.disposed = false;
    this.ensureParticles();
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.stopTick();
  }

  private stopTick(): void {
    if (this.tickTimerId >= 0) {
      clearInterval(this.tickTimerId);
      this.tickTimerId = -1;
    }
  }

  private startTick(): void {
    this.stopTick();
    this.tickTimerId = setInterval(() => {
      if (this.disposed || !this.active) {
        return;
      }
      this.drawFrame();
    }, FRAME_MS) as number;
  }

  private ensureParticles(): void {
    if (this.particles.length > 0) {
      return;
    }
    const phi = Math.PI * (3 - Math.sqrt(5));
    for (let i = 0; i < PARTICLE_COUNT; i++) {
      const t = i / (PARTICLE_COUNT - 1);
      const y = 1 - t * 2;
      const ring = Math.sqrt(Math.max(0, 1 - y * y));
      const theta = phi * i;
      this.particles.push({
        x: Math.cos(theta) * ring * SPHERE_RADIUS,
        y: y * SPHERE_RADIUS,
        z: Math.sin(theta) * ring * SPHERE_RADIUS
      });
    }
  }

  private project(x: number, y: number, z: number, rotY: number, rotX: number, cx: number,
    cy: number): ProjectedPoint {
    let xr = x * Math.cos(rotY) - z * Math.sin(rotY);
    let zr = x * Math.sin(rotY) + z * Math.cos(rotY);
    let yr = y;
    let y2 = yr * Math.cos(rotX) - zr * Math.sin(rotX);
    let z2 = yr * Math.sin(rotX) + zr * Math.cos(rotX);
    const perspective = 300 / (300 + z2 * 130);
    return {
      sx: cx + xr * 98 * perspective,
      sy: cy + y2 * 98 * perspective,
      z: z2
    };
  }

  private drawOrbit(ctx: CanvasRenderingContext2D, cx: number, cy: number, radius: number, tilt: number,
    rotY: number, rotX: number, alpha: number): void {
    ctx.beginPath();
    for (let i = 0; i <= 72; i++) {
      const a = (i / 72) * Math.PI * 2;
      const x = Math.cos(a) * radius;
      const z = Math.sin(a) * radius;
      const y = Math.sin(a * 2 + tilt) * 0.12;
      const p = this.project(x, y, z, rotY, rotX, cx, cy);
      if (i === 0) {
        ctx.moveTo(p.sx, p.sy);
      } else {
        ctx.lineTo(p.sx, p.sy);
      }
    }
    ctx.closePath();
    ctx.strokeStyle = `rgba(0, 102, 204, ${alpha})`;
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  private drawFrame(): void {
    const ctx = this.ctx;
    const w = CANVAS_SIZE;
    const h = CANVAS_SIZE;
    const cx = w / 2;
    const cy = h / 2;
    const elapsed = (Date.now() - this.startMs) / 1000;
    const rotY = elapsed * 0.55;
    const rotX = 0.42 + Math.sin(elapsed * 0.35) * 0.12;

    ctx.clearRect(0, 0, w, h);

    const guideRadii: number[] = [42, 72, 102];
    for (const r of guideRadii) {
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.strokeStyle = AppleTheme.HAIRLINE;
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    this.drawOrbit(ctx, cx, cy, 0.92, 0, rotY, rotX, 0.22);
    this.drawOrbit(ctx, cx, cy, 0.72, 1.2, rotY + 0.8, rotX, 0.16);
    this.drawOrbit(ctx, cx, cy, 0.55, 2.1, rotY + 1.6, rotX, 0.12);

    const pulseT = (elapsed % 2.2) / 2.2;
    ctx.beginPath();
    ctx.arc(cx, cy, 28 + pulseT * 88, 0, Math.PI * 2);
    ctx.strokeStyle = `rgba(0, 102, 204, ${0.45 * (1 - pulseT)})`;
    ctx.lineWidth = 2;
    ctx.stroke();

    const projected: ProjectedPoint[] = [];
    for (let i = 0; i < this.particles.length; i++) {
      const p = this.particles[i];
      projected.push(this.project(p.x, p.y, p.z, rotY, rotX, cx, cy));
    }
    projected.sort((a, b) => a.z - b.z);

    for (let i = 0; i < projected.length; i++) {
      const a = projected[i];
      if (a.z < -0.15) {
        continue;
      }
      for (let j = i + 1; j < projected.length; j++) {
        const b = projected[j];
        if (b.z < -0.15) {
          continue;
        }
        const dx = a.sx - b.sx;
        const dy = a.sy - b.sy;
        if (dx * dx + dy * dy < 55 * 55) {
          const depth = ((a.z + b.z) / 2 + 1) * 0.5;
          ctx.beginPath();
          ctx.moveTo(a.sx, a.sy);
          ctx.lineTo(b.sx, b.sy);
          ctx.strokeStyle = `rgba(0, 102, 204, ${0.06 + depth * 0.14})`;
          ctx.lineWidth = 1;
          ctx.stroke();
        }
      }
    }

    for (const pt of projected) {
      const depth = (pt.z + 1) * 0.5;
      const radius = 1.5 + depth * 4.5;
      const alpha = 0.2 + depth * 0.8;
      ctx.beginPath();
      ctx.arc(pt.sx, pt.sy, radius * 2.2, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(0, 102, 204, ${alpha * 0.18})`;
      ctx.fill();
      ctx.beginPath();
      ctx.arc(pt.sx, pt.sy, radius, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(0, 102, 204, ${alpha})`;
      ctx.fill();
    }

    for (const pt of projected) {
      if (pt.z > 0.35) {
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.lineTo(pt.sx, pt.sy);
        ctx.strokeStyle = `rgba(0, 102, 204, ${0.05 + (pt.z + 1) * 0.08})`;
        ctx.lineWidth = 1;
        ctx.stroke();
      }
    }

    ctx.beginPath();
    ctx.arc(cx, cy, 24, 0, Math.PI * 2);
    ctx.fillStyle = AppleTheme.PRIMARY;
    ctx.fill();
    ctx.fillStyle = AppleTheme.CANVAS;
    ctx.font = 'bold 14vp sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('BT', cx, cy);
  }

  build() {
    Canvas(this.ctx)
      .width(CANVAS_SIZE)
      .height(CANVAS_SIZE)
      .accessibilityLevel('no')
      .onReady(() => {
        if (this.disposed) {
          return;
        }
        this.ensureParticles();
        this.startMs = Date.now();
        if (this.active) {
          this.drawFrame();
          this.startTick();
        }
      })
  }
}
