import { describe, beforeEach, it, expect } from '@ohos/hypium';
import {
  ScanFilter,
  ScanFilterHolder,
  ScanFilterTarget,
  defaultScanFilter,
  matchesFilter
} from '../main/ets/features/advert/domain/ScanFilter';

const UUID_DEVICE_INFO: string = '0000180a-0000-1000-8000-00805f9b34fb';
const UUID_HEART_RATE: string = '0000180d-0000-1000-8000-00805f9b34fb';
const MFG_APPLEISH: string = '57:01:02';

function target(connectable: boolean, uuids: string[], manufacturerHex: string): ScanFilterTarget {
  const device: ScanFilterTarget = {
    connectable: connectable,
    advertServiceUuids: uuids.slice(),
    advertManufacturerHex: manufacturerHex
  };
  return device;
}

function filterOf(serviceUuid: string, manufacturerId: string, connectableOnly: boolean): ScanFilter {
  const filter: ScanFilter = {
    serviceUuid: serviceUuid,
    manufacturerId: manufacturerId,
    connectableOnly: connectableOnly
  };
  return filter;
}

export default function scanFilterTest() {
  describe('ScanFilter', () => {
    beforeEach(() => {
      ScanFilterHolder.set(defaultScanFilter());
    });

    it('defaultFilterShowsAllDevices', 0, () => {
      const filter: ScanFilter = defaultScanFilter();
      expect(filter.connectableOnly).assertFalse();
      expect(filter.serviceUuid === undefined || filter.serviceUuid.length === 0).assertTrue();
      expect(filter.manufacturerId === undefined || filter.manufacturerId.length === 0).assertTrue();
      expect(matchesFilter(target(true, [UUID_DEVICE_INFO], MFG_APPLEISH), filter)).assertTrue();
      expect(matchesFilter(target(false, [], ''), filter)).assertTrue();
    });

    it('serviceUuidMatchesFullAndShortForm', 0, () => {
      const device: ScanFilterTarget = target(true, [UUID_DEVICE_INFO], '');
      expect(matchesFilter(device, filterOf(UUID_DEVICE_INFO, '', false))).assertTrue();
      expect(matchesFilter(device, filterOf('180a', '', false))).assertTrue();
      expect(matchesFilter(device, filterOf('180A', '', false))).assertTrue();
      expect(matchesFilter(device, filterOf(UUID_HEART_RATE, '', false))).assertFalse();
      expect(matchesFilter(device, filterOf('180d', '', false))).assertFalse();
    });

    it('serviceUuidUnsetDoesNotRestrict', 0, () => {
      const device: ScanFilterTarget = target(true, [], '');
      expect(matchesFilter(device, filterOf('', '', false))).assertTrue();
      expect(matchesFilter(device, filterOf('   ', '', false))).assertTrue();
    });

    it('manufacturerIdMatchesColonOrBareHex', 0, () => {
      const device: ScanFilterTarget = target(true, [], MFG_APPLEISH);
      expect(matchesFilter(device, filterOf('', '57:01', false))).assertTrue();
      expect(matchesFilter(device, filterOf('', '5701', false))).assertTrue();
      expect(matchesFilter(device, filterOf('', '57:01:02', false))).assertTrue();
      expect(matchesFilter(device, filterOf('', '99:99', false))).assertFalse();
      expect(matchesFilter(device, filterOf('', '0157', false))).assertFalse();
    });

    it('manufacturerIdUnsetDoesNotRestrict', 0, () => {
      const device: ScanFilterTarget = target(true, [], '');
      expect(matchesFilter(device, filterOf('', '', false))).assertTrue();
      expect(matchesFilter(device, filterOf('', '  ', false))).assertTrue();
    });

    it('connectableOnlyHidesBroadcastOnly', 0, () => {
      const connectable: ScanFilterTarget = target(true, [], '');
      const broadcast: ScanFilterTarget = target(false, [], '');
      expect(matchesFilter(connectable, filterOf('', '', true))).assertTrue();
      expect(matchesFilter(broadcast, filterOf('', '', true))).assertFalse();
      expect(matchesFilter(broadcast, filterOf('', '', false))).assertTrue();
    });

    it('andRequiresEverySetCondition', 0, () => {
      const matching: ScanFilterTarget = target(true, [UUID_DEVICE_INFO], MFG_APPLEISH);
      const allSet: ScanFilter = filterOf('180a', '57:01', true);
      expect(matchesFilter(matching, allSet)).assertTrue();
      expect(matchesFilter(target(false, [UUID_DEVICE_INFO], MFG_APPLEISH), allSet)).assertFalse();
      expect(matchesFilter(target(true, [UUID_HEART_RATE], MFG_APPLEISH), allSet)).assertFalse();
      expect(matchesFilter(target(true, [UUID_DEVICE_INFO], '99:99'), allSet)).assertFalse();
    });

    it('andKeepsUnsetConditionsOut', 0, () => {
      const uuidAndMfg: ScanFilter = filterOf('180a', '57:01', false);
      expect(matchesFilter(target(false, [UUID_DEVICE_INFO], MFG_APPLEISH), uuidAndMfg)).assertTrue();
      expect(matchesFilter(target(true, [UUID_DEVICE_INFO], '99:99'), uuidAndMfg)).assertFalse();
    });

    it('holderDefaultsEmptyAndNotConnectableOnly', 0, () => {
      const current: ScanFilter = ScanFilterHolder.current();
      expect(current.connectableOnly).assertFalse();
      expect(current.serviceUuid === undefined || current.serviceUuid.length === 0).assertTrue();
      expect(current.manufacturerId === undefined || current.manufacturerId.length === 0).assertTrue();
    });

    it('holderSetIsVisibleToCurrent', 0, () => {
      ScanFilterHolder.set(filterOf('180a', '57:01', true));
      const current: ScanFilter = ScanFilterHolder.current();
      expect(current.serviceUuid).assertEqual('180a');
      expect(current.manufacturerId).assertEqual('57:01');
      expect(current.connectableOnly).assertTrue();
    });
  });
}
