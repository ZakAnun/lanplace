import { describe, it, expect } from '@ohos/hypium';
import { bytesToHex, hexToBytes } from '../main/ets/shared/ble/BytesHex';

function sameBytes(actual: Uint8Array, expected: number[]): boolean {
  if (actual.length !== expected.length) {
    return false;
  }
  for (let i = 0; i < expected.length; i++) {
    if (actual[i] !== expected[i]) {
      return false;
    }
  }
  return true;
}

export default function bytesHexTest() {
  describe('BytesHex', () => {
    it('bytesToHex_emptyIsEmpty', 0, () => {
      expect(bytesToHex(new Uint8Array(0))).assertEqual('');
    });

    it('bytesToHex_formatsUpperColonPairs', 0, () => {
      const bytes: Uint8Array = new Uint8Array([0x00, 0x0a, 0xff]);
      expect(bytesToHex(bytes)).assertEqual('00:0A:FF');
    });

    it('hexToBytes_emptyIsEmpty', 0, () => {
      expect(sameBytes(hexToBytes(''), [])).assertTrue();
      expect(sameBytes(hexToBytes('   '), [])).assertTrue();
    });

    it('hexToBytes_acceptsColonSpaceOrBare', 0, () => {
      expect(sameBytes(hexToBytes('00:0A:FF'), [0x00, 0x0a, 0xff])).assertTrue();
      expect(sameBytes(hexToBytes('00 0a ff'), [0x00, 0x0a, 0xff])).assertTrue();
      expect(sameBytes(hexToBytes('000aff'), [0x00, 0x0a, 0xff])).assertTrue();
    });

    it('hexToBytes_rejectsInvalidHex', 0, () => {
      const samples: string[] = ['0', 'zz', '00:0G', '0A:F', '0x00'];
      for (let i = 0; i < samples.length; i++) {
        let threw: boolean = false;
        try {
          hexToBytes(samples[i]);
        } catch (_err) {
          threw = true;
        }
        expect(threw).assertTrue();
      }
    });
  });
}
