import { RssiSample } from './RssiRingBuffer';

export interface AdvertSnapshot {
  localName: string;
  advertSummary: string;
}

export interface AdvertRssiStore {
  push(deviceKey: string, ts: number, rssi: number): void;
  samples(deviceKey: string): RssiSample[];
  recordSnapshot(deviceKey: string, snapshot: AdvertSnapshot): void;
  snapshot(deviceKey: string): AdvertSnapshot | null;
}

export class AdvertHistory {
  private static store: AdvertRssiStore | null = null;

  static bindStore(store: AdvertRssiStore): void {
    AdvertHistory.store = store;
  }

  static push(deviceKey: string, ts: number, rssi: number): void {
    const impl: AdvertRssiStore | null = AdvertHistory.store;
    if (impl !== null) {
      impl.push(deviceKey, ts, rssi);
    }
  }

  static samples(deviceKey: string): RssiSample[] {
    const impl: AdvertRssiStore | null = AdvertHistory.store;
    if (impl === null) {
      return [];
    }
    return impl.samples(deviceKey);
  }

  static recordSnapshot(deviceKey: string, snapshot: AdvertSnapshot): void {
    const impl: AdvertRssiStore | null = AdvertHistory.store;
    if (impl !== null) {
      impl.recordSnapshot(deviceKey, snapshot);
    }
  }

  static snapshot(deviceKey: string): AdvertSnapshot | null {
    const impl: AdvertRssiStore | null = AdvertHistory.store;
    if (impl === null) {
      return null;
    }
    return impl.snapshot(deviceKey);
  }
}
