import { AdvertRssiStore, AdvertSnapshot } from '../domain/AdvertHistory';
import { RssiRingBuffer, RssiSample } from '../domain/RssiRingBuffer';

export class AdvertHistoryStore implements AdvertRssiStore {
  private readonly buffers: Map<string, RssiRingBuffer> = new Map();
  private readonly snapshots: Map<string, AdvertSnapshot> = new Map();

  push(deviceKey: string, ts: number, rssi: number): void {
    let buf: RssiRingBuffer | undefined = this.buffers.get(deviceKey);
    if (buf === undefined) {
      buf = new RssiRingBuffer();
      this.buffers.set(deviceKey, buf);
    }
    buf.push(ts, rssi);
  }

  samples(deviceKey: string): RssiSample[] {
    const buf: RssiRingBuffer | undefined = this.buffers.get(deviceKey);
    if (buf === undefined) {
      return [];
    }
    return buf.samples();
  }

  recordSnapshot(deviceKey: string, snapshot: AdvertSnapshot): void {
    this.snapshots.set(deviceKey, snapshot);
  }

  snapshot(deviceKey: string): AdvertSnapshot | null {
    const found: AdvertSnapshot | undefined = this.snapshots.get(deviceKey);
    if (found === undefined) {
      return null;
    }
    return found;
  }
}
