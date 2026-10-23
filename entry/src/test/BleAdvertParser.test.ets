import { describe, it, expect } from '@ohos/hypium';
import { parseAdvertData } from '../main/ets/common/BleAdvertParser';

export default function bleAdvertParserTest() {
  describe('BleAdvertParser', () => {
    it('parses_complete_local_name', 0, () => {
      const name = 'Test';
      const ad: number[] = [name.length + 1, 0x09, ...Array.from(name).map(c => c.charCodeAt(0))];
      const buf = new Uint8Array(ad).buffer;
      const parsed = parseAdvertData(buf);
      expect(parsed.localName).assertEqual('Test');
    });
  });
}
