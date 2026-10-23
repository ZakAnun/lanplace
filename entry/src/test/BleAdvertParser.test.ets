import { describe, it, expect } from '@ohos/hypium';
import { mergeScanResult, parseAdvertData } from '../main/ets/common/BleAdvertParser';

export default function bleAdvertParserTest() {
  describe('BleAdvertParser', () => {
    it('parses_complete_local_name', 0, () => {
      const name = 'Test';
      const ad: number[] = [name.length + 1, 0x09, ...Array.from(name).map(c => c.charCodeAt(0))];
      const buf = new Uint8Array(ad).buffer;
      const parsed = parseAdvertData(buf);
      expect(parsed.localName).assertEqual('Test');
    });

    it('parses_tx_power_signed', 0, () => {
      const ad: number[] = [2, 0x0A, 0xF4];
      const parsed = parseAdvertData(new Uint8Array(ad).buffer);
      expect(parsed.txPower).assertEqual(-12);
    });

    it('parses_uuid16_little_endian', 0, () => {
      const ad: number[] = [3, 0x03, 0x0A, 0x18];
      const parsed = parseAdvertData(new Uint8Array(ad).buffer);
      expect(parsed.serviceUuids.length).assertEqual(1);
      expect(parsed.serviceUuids[0]).assertContain('180a');
    });

    it('mergeScanResult_prefers_advert_name', 0, () => {
      const ad: number[] = [5, 0x09, ...Array.from('AdvName').map(c => c.charCodeAt(0))];
      const merged = mergeScanResult('id-1', '', -55, true, new Uint8Array(ad).buffer);
      expect(merged.displayName).assertEqual('AdvName');
      expect(merged.rssi).assertEqual(-55);
    });
  });
}
