import { describe, it, expect } from '@ohos/hypium';
import { mergeScanResult, parseAdvertData } from '../main/ets/shared/ble/BleAdvertParser';
import { ScanUiLabels } from '../main/ets/shared/platform/ScanUiLabels';
import { DeviceLinkState } from '../main/ets/shared/ble/ScannedDevice';

function advertBytesToBuffer(ad: number[]): ArrayBuffer {
  const copy: ArrayBuffer = new ArrayBuffer(ad.length);
  const view: Uint8Array = new Uint8Array(copy);
  for (let i = 0; i < ad.length; i++) {
    view[i] = ad[i];
  }
  return copy;
}

export default function bleAdvertParserTest() {
  describe('BleAdvertParser', () => {
    it('parses_complete_local_name', 0, () => {
      const name = 'Test';
      const ad: number[] = [name.length + 1, 0x09, ...Array.from(name).map(c => c.charCodeAt(0))];
      const parsed = parseAdvertData(advertBytesToBuffer(ad));
      expect(parsed.localName).assertEqual('Test');
    });

    it('parses_tx_power_signed', 0, () => {
      const ad: number[] = [2, 0x0A, 0xF4];
      const parsed = parseAdvertData(advertBytesToBuffer(ad));
      expect(parsed.txPower).assertEqual(-12);
    });

    it('parses_uuid16_little_endian', 0, () => {
      const ad: number[] = [3, 0x03, 0x0A, 0x18];
      const parsed = parseAdvertData(advertBytesToBuffer(ad));
      expect(parsed.serviceUuids.length).assertEqual(1);
      expect(parsed.serviceUuids[0]).assertContain('180a');
    });

    it('parses_uuid128_little_endian', 0, () => {
      const uuidBytes: number[] = [
        0xFB, 0x34, 0x9B, 0x5F, 0x80, 0x00, 0x00, 0x80,
        0x00, 0x10, 0x00, 0x00, 0x0D, 0x18, 0x00, 0x00
      ];
      const ad: number[] = [17, 0x06, ...uuidBytes];
      const parsed = parseAdvertData(advertBytesToBuffer(ad));
      expect(parsed.serviceUuids.length).assertEqual(1);
      expect(parsed.serviceUuids[0]).assertEqual('0000180d-0000-1000-8000-00805f9b34fb');
    });

    it('mergeScanResult_prefers_advert_name', 0, () => {
      const name = 'AdvName';
      const ad: number[] = [name.length + 1, 0x09, ...Array.from(name).map(c => c.charCodeAt(0))];
      const merged = mergeScanResult('id-1', '', -55, true, advertBytesToBuffer(ad));
      expect(merged.displayName).assertEqual('AdvName');
      expect(merged.rssi).assertEqual(-55);
      expect(merged.linkState).assertEqual(DeviceLinkState.Available);
    });

    it('mergeScanResult_uses_locale_fallback_name', 0, () => {
      ScanUiLabels.unknownDevice = 'Unknown device';
      ScanUiLabels.connectable = 'Connectable';
      const merged = mergeScanResult('id-2', '', -70, true, advertBytesToBuffer([]));
      expect(merged.displayName).assertEqual('Unknown device');
      expect(merged.detailLine).assertContain('Connectable');
    });
  });
}
