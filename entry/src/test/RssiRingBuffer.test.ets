import { describe, it, expect } from '@ohos/hypium';
import {
  RSSI_MAX_SAMPLES,
  RSSI_WINDOW_MS,
  RssiRingBuffer,
  RssiSample
} from '../main/ets/features/advert/domain/RssiRingBuffer';

export default function rssiRingBufferTest() {
  describe('RssiRingBuffer', () => {
    it('windowConstantIsThreeMinutes', 0, () => {
      expect(RSSI_WINDOW_MS).assertEqual(180_000);
    });

    it('dropsSamplesOlderThanWindow', 0, () => {
      const buf: RssiRingBuffer = new RssiRingBuffer();
      buf.push(0, -40);
      buf.push(RSSI_WINDOW_MS, -50);
      buf.push(RSSI_WINDOW_MS + 1, -60);
      const out: RssiSample[] = buf.samples();
      expect(out.length).assertEqual(2);
      expect(out[0].ts).assertEqual(RSSI_WINDOW_MS);
      expect(out[0].rssi).assertEqual(-50);
      expect(out[1].ts).assertEqual(RSSI_WINDOW_MS + 1);
      expect(out[1].rssi).assertEqual(-60);
    });

    it('capsAtMaxSamples', 0, () => {
      const buf: RssiRingBuffer = new RssiRingBuffer();
      expect(RSSI_MAX_SAMPLES).assertEqual(360);
      for (let i = 0; i < RSSI_MAX_SAMPLES + 5; i++) {
        buf.push(i, -40 - (i % 10));
      }
      const out: RssiSample[] = buf.samples();
      expect(out.length).assertEqual(RSSI_MAX_SAMPLES);
      expect(out[0].ts).assertEqual(5);
      expect(out[out.length - 1].ts).assertEqual(RSSI_MAX_SAMPLES + 4);
    });
  });
}
