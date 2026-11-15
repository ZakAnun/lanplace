import { describe, it, expect } from '@ohos/hypium';
import { DeviceLinkState } from '../main/ets/shared/ble/ScannedDevice';
import { HomeInventoryDevice, InventoryDeviceKind } from '../main/ets/features/discovery/domain/HomeInventoryDevice';
import { bleInventoryKey } from '../main/ets/features/discovery/domain/InventoryDeviceMerge';
import { applyConnectedBadge } from '../main/ets/features/discovery/domain/mergeRegistryLinkState';

const BLE_ID: string = '11:22:33:44:55:66';

function bleOf(deviceId: string, linkState: DeviceLinkState): HomeInventoryDevice {
  const device: HomeInventoryDevice = {
    deviceKey: bleInventoryKey(deviceId),
    kind: InventoryDeviceKind.Ble,
    displayName: 'Band',
    detailLine: '-48 dBm',
    extraLine: '',
    rssi: -48,
    linkState: linkState
  };
  return device;
}

function lanOf(deviceKey: string): HomeInventoryDevice {
  const device: HomeInventoryDevice = {
    deviceKey: deviceKey,
    kind: InventoryDeviceKind.Lan,
    displayName: 'Printer',
    detailLine: '192.168.1.8:80',
    extraLine: '_http._tcp',
    rssi: 0,
    linkState: DeviceLinkState.Discovered
  };
  return device;
}

export default function mergeRegistryLinkStateTest() {
  describe('mergeRegistryLinkState', () => {
    it('bleKeyInConnectedIdsMarksConnected', 0, () => {
      const devices: HomeInventoryDevice[] = [bleOf(BLE_ID, DeviceLinkState.Available)];
      const connectedIds: Set<string> = new Set();
      connectedIds.add(bleInventoryKey(BLE_ID));
      const out: HomeInventoryDevice[] = applyConnectedBadge(devices, connectedIds);
      expect(out[0].linkState).assertEqual(DeviceLinkState.Connected);
    });

    it('unlistedBleKeepsOriginalLinkState', 0, () => {
      const devices: HomeInventoryDevice[] = [bleOf(BLE_ID, DeviceLinkState.Available)];
      const connectedIds: Set<string> = new Set();
      const out: HomeInventoryDevice[] = applyConnectedBadge(devices, connectedIds);
      expect(out[0].linkState).assertEqual(DeviceLinkState.Available);
    });

    it('rawBleDeviceIdDoesNotMatchInventoryKey', 0, () => {
      const devices: HomeInventoryDevice[] = [bleOf(BLE_ID, DeviceLinkState.Available)];
      const connectedIds: Set<string> = new Set();
      connectedIds.add(BLE_ID);
      const out: HomeInventoryDevice[] = applyConnectedBadge(devices, connectedIds);
      expect(out[0].linkState).assertEqual(DeviceLinkState.Available);
    });

    it('lanDeviceIsNotMarkedConnected', 0, () => {
      const lanKey: string = 'lan:host:192.168.1.8';
      const devices: HomeInventoryDevice[] = [lanOf(lanKey)];
      const connectedIds: Set<string> = new Set();
      connectedIds.add(lanKey);
      const out: HomeInventoryDevice[] = applyConnectedBadge(devices, connectedIds);
      expect(out[0].linkState).assertEqual(DeviceLinkState.Discovered);
    });

    it('doesNotMutateInputDevices', 0, () => {
      const devices: HomeInventoryDevice[] = [bleOf(BLE_ID, DeviceLinkState.Available)];
      const connectedIds: Set<string> = new Set();
      connectedIds.add(bleInventoryKey(BLE_ID));
      applyConnectedBadge(devices, connectedIds);
      expect(devices[0].linkState).assertEqual(DeviceLinkState.Available);
    });
  });
}
