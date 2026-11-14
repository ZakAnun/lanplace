import { describe, it, expect } from '@ohos/hypium';
import { mergeScanResult, parseAdvertData } from '../main/ets/shared/ble/BleAdvertParser';
import {
  AdvertHistory,
  AdvertSnapshot,
  advertSnapshotFromParsed
} from '../main/ets/features/advert/domain/AdvertHistory';
import { AdvertHistoryStore } from '../main/ets/features/advert/data/AdvertHistoryStore';

function advertBytesToBuffer(ad: number[]): ArrayBuffer {
  const copy: ArrayBuffer = new ArrayBuffer(ad.length);
  const view: Uint8Array = new Uint8Array(copy);
  for (let i = 0; i < ad.length; i++) {
    view[i] = ad[i];
  }
  return copy;
}

function flagsTxUuidMfgSvcAd(): number[] {
  return [
    2, 0x01, 0x06,
    2, 0x0A, 0xF4,
    3, 0x03, 0x0A, 0x18,
    4, 0xFF, 0x57, 0x01, 0x02,
    5, 0x16, 0x09, 0x18, 0x01, 0x02
  ];
}

export default function advertHistoryTest() {
  describe('AdvertHistory', () => {
    it('snapshotKeepsStructuredParsedAdvertFields', 0, () => {
      AdvertHistory.bindStore(new AdvertHistoryStore());
      const recorded: AdvertSnapshot = {
        flags: 0x06,
        localName: 'KitchenSensor',
        txPower: -4,
        serviceUuids: ['0000180a-0000-1000-8000-00805f9b34fb'],
        manufacturerHex: '57:01:02',
        serviceDataHex: '09:18:01:02'
      };
      AdvertHistory.recordSnapshot('ble:dev', recorded);
      const snap: AdvertSnapshot | null = AdvertHistory.snapshot('ble:dev');
      expect(snap !== null).assertTrue();
      const fields: AdvertSnapshot = snap as AdvertSnapshot;
      expect(fields.localName).assertEqual('KitchenSensor');
      expect(fields.flags).assertEqual(0x06);
      expect(fields.txPower).assertEqual(-4);
      expect(fields.serviceUuids.length).assertEqual(1);
      expect(fields.serviceUuids[0]).assertContain('180a');
      expect(fields.manufacturerHex).assertEqual('57:01:02');
      expect(fields.serviceDataHex).assertEqual('09:18:01:02');
    });

    it('snapshotFromParsedAdvertKeepsTxPowerAndUuids', 0, () => {
      AdvertHistory.bindStore(new AdvertHistoryStore());
      const parsed = parseAdvertData(advertBytesToBuffer(flagsTxUuidMfgSvcAd()));
      AdvertHistory.recordSnapshot('ble:parsed', advertSnapshotFromParsed(parsed));
      const snap: AdvertSnapshot | null = AdvertHistory.snapshot('ble:parsed');
      expect(snap !== null).assertTrue();
      const fields: AdvertSnapshot = snap as AdvertSnapshot;
      expect(fields.flags).assertEqual(0x06);
      expect(fields.txPower).assertEqual(-12);
      expect(fields.serviceUuids.length).assertEqual(1);
      expect(fields.serviceUuids[0]).assertContain('180a');
      expect(fields.manufacturerHex).assertEqual('57:01:02');
      expect(fields.serviceDataHex).assertEqual('09:18:01:02');
    });

    it('mergeScanResultCarriesParsedFieldsOnDevice', 0, () => {
      const merged = mergeScanResult(
        'id-carry',
        'OsName',
        -50,
        true,
        advertBytesToBuffer(flagsTxUuidMfgSvcAd())
      );
      expect(merged.displayName).assertEqual('OsName');
      expect(merged.advertFlags).assertEqual(0x06);
      expect(merged.advertTxPower).assertEqual(-12);
      expect(merged.advertServiceUuids.length).assertEqual(1);
      expect(merged.advertServiceUuids[0]).assertContain('180a');
      expect(merged.advertManufacturerHex).assertEqual('57:01:02');
      expect(merged.advertServiceDataHex).assertEqual('09:18:01:02');
    });
  });
}
