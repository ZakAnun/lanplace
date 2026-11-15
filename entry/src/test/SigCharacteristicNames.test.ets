import { describe, it, expect } from '@ohos/hypium';
import { sigCharacteristicName } from '../main/ets/features/gatt/domain/SigCharacteristicNames';

const HEART_RATE_UUID: string = '00002a37-0000-1000-8000-00805f9b34fb';
const TEMPERATURE_UUID: string = '00002A6E-0000-1000-8000-00805F9B34FB';

export default function sigCharacteristicNamesTest() {
  describe('SigCharacteristicNames', () => {
    it('mapsHeartRateMeasurement2A37', 0, () => {
      expect(sigCharacteristicName('2A37')).assertEqual('Heart Rate Measurement');
      expect(sigCharacteristicName('0x2A37')).assertEqual('Heart Rate Measurement');
      expect(sigCharacteristicName(HEART_RATE_UUID)).assertEqual('Heart Rate Measurement');
    });

    it('mapsTemperature2A6E', 0, () => {
      expect(sigCharacteristicName('2a6e')).assertEqual('Temperature');
      expect(sigCharacteristicName('0x2A6E')).assertEqual('Temperature');
      expect(sigCharacteristicName(TEMPERATURE_UUID)).assertEqual('Temperature');
    });

    it('unmappedUuidIsEmpty', 0, () => {
      expect(sigCharacteristicName('2A19')).assertEqual('');
      expect(sigCharacteristicName('0000180f-0000-1000-8000-00805f9b34fb')).assertEqual('');
      expect(sigCharacteristicName('')).assertEqual('');
    });
  });
}
