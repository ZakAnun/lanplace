export const RSSI_WINDOW_MS: number = 180_000;
export const RSSI_MAX_SAMPLES: number = 360;

export interface RssiSample {
  ts: number;
  rssi: number;
}

export class RssiRingBuffer {
  private readonly items: RssiSample[] = [];

  push(ts: number, rssi: number): void {
    const sample: RssiSample = {
      ts: ts,
      rssi: rssi
    };
    this.items.push(sample);
    this.trim(ts);
  }

  samples(): RssiSample[] {
    return this.items.slice();
  }

  private trim(now: number): void {
    const cutoff: number = now - RSSI_WINDOW_MS;
    while (this.items.length > 0 && this.items[0].ts < cutoff) {
      this.items.shift();
    }
    while (this.items.length > RSSI_MAX_SAMPLES) {
      this.items.shift();
    }
  }
}
