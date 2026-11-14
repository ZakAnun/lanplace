import { common } from '@kit.AbilityKit';
import { AdvertHistory } from '../../advert/domain/AdvertHistory';
import { SCAN_TIMEOUT_MS } from '../../../shared/platform/Constants';
import {
  HomeInventoryDevice,
  InventoryDeviceKind
} from '../domain/HomeInventoryDevice';
import { ScannedDevice } from '../../../shared/ble/ScannedDevice';
import { bleInventoryKey } from '../domain/InventoryDeviceMerge';
import { ScanUiLabels } from '../../../shared/platform/ScanUiLabels';
import { BleScanCoordinator } from './BleScanCoordinator';
import { BLE_SCAN_STOP_QUIET } from './BleScanService';
import { LanDiscoveredDevice, MdnsScanService } from './MdnsScanService';

type InventoryUpdateCallback = (devices: HomeInventoryDevice[]) => void;
type InventoryCompleteCallback = () => void;

export class HomeInventoryCoordinator {
  private static running: boolean = false;
  private static endTimerId: number = -1;
  private static bleDevices: ScannedDevice[] = [];
  private static lanDevices: LanDiscoveredDevice[] = [];
  private static onUpdate: InventoryUpdateCallback = () => {};
  private static onComplete: InventoryCompleteCallback = () => {};

  static isScanning(): boolean {
    return HomeInventoryCoordinator.running;
  }

  static snapshotDevices(): HomeInventoryDevice[] {
    return HomeInventoryCoordinator.mergeDevices();
  }

  private static mergeDevices(): HomeInventoryDevice[] {
    const merged: HomeInventoryDevice[] = [];
    for (let i = 0; i < HomeInventoryCoordinator.bleDevices.length; i++) {
      const d = HomeInventoryCoordinator.bleDevices[i];
      merged.push({
        deviceKey: bleInventoryKey(d.deviceId),
        kind: InventoryDeviceKind.Ble,
        displayName: d.displayName.length > 0 ? d.displayName : ScanUiLabels.unknownBleDevice,
        detailLine: d.detailLine,
        extraLine: d.advertSummary,
        rssi: d.rssi
      });
    }
    for (let i = 0; i < HomeInventoryCoordinator.lanDevices.length; i++) {
      const d = HomeInventoryCoordinator.lanDevices[i];
      merged.push({
        deviceKey: d.deviceKey,
        kind: InventoryDeviceKind.Lan,
        displayName: d.displayName,
        detailLine: `${d.hostAddress}:${d.port}`,
        extraLine: d.serviceTypes.join(' · '),
        rssi: 0
      });
    }
    return merged;
  }

  private static emitUpdate(): void {
    HomeInventoryCoordinator.onUpdate(HomeInventoryCoordinator.mergeDevices());
  }

  private static recordBleHistory(list: ScannedDevice[]): void {
    const now: number = Date.now();
    for (let i = 0; i < list.length; i++) {
      const d: ScannedDevice = list[i];
      const key: string = bleInventoryKey(d.deviceId);
      AdvertHistory.push(key, now, d.rssi);
      AdvertHistory.recordSnapshot(key, {
        flags: d.advertFlags,
        localName: d.advertLocalName,
        txPower: d.advertTxPower,
        serviceUuids: d.advertServiceUuids.slice(),
        manufacturerHex: d.advertManufacturerHex,
        serviceDataHex: d.advertServiceDataHex
      });
    }
  }

  private static clearTimer(): void {
    if (HomeInventoryCoordinator.endTimerId >= 0) {
      clearTimeout(HomeInventoryCoordinator.endTimerId);
      HomeInventoryCoordinator.endTimerId = -1;
    }
  }

  static start(context: common.Context, onUpdate: InventoryUpdateCallback,
    onComplete?: InventoryCompleteCallback, enableBleScan: boolean = true,
    enableLanScan: boolean = true): boolean {
    if (HomeInventoryCoordinator.running) {
      return false;
    }
    ScanUiLabels.load(context);
    HomeInventoryCoordinator.onUpdate = onUpdate;
    HomeInventoryCoordinator.onComplete = onComplete ?? (() => {});
    HomeInventoryCoordinator.bleDevices = [];
    HomeInventoryCoordinator.lanDevices = [];

    let mdnsStarted = false;
    if (enableLanScan) {
      mdnsStarted = MdnsScanService.start(context, (list: LanDiscoveredDevice[]) => {
        HomeInventoryCoordinator.lanDevices = list.slice();
        HomeInventoryCoordinator.emitUpdate();
      });
    }

    let bleStarted = false;
    if (enableBleScan) {
      try {
        bleStarted = BleScanCoordinator.start(
          (list: ScannedDevice[]) => {
            HomeInventoryCoordinator.bleDevices = list.slice();
            HomeInventoryCoordinator.recordBleHistory(list);
            HomeInventoryCoordinator.emitUpdate();
          },
          () => {
            // BLE 自然结束时不单独结束整次扫描
          }
        );
      } catch (_err) {
        bleStarted = false;
      }
    }

    if (!mdnsStarted && !bleStarted) {
      HomeInventoryCoordinator.onUpdate = () => {};
      HomeInventoryCoordinator.onComplete = () => {};
      MdnsScanService.stop();
      return false;
    }

    HomeInventoryCoordinator.running = true;
    HomeInventoryCoordinator.clearTimer();
    HomeInventoryCoordinator.endTimerId = setTimeout(() => {
      HomeInventoryCoordinator.stop(true);
    }, SCAN_TIMEOUT_MS) as number;

    HomeInventoryCoordinator.emitUpdate();
    return true;
  }

  static stop(notifyComplete: boolean = true): void {
    if (!HomeInventoryCoordinator.running) {
      return;
    }
    HomeInventoryCoordinator.running = false;
    HomeInventoryCoordinator.clearTimer();

    BleScanCoordinator.stop(BLE_SCAN_STOP_QUIET);
    MdnsScanService.stop();

    HomeInventoryCoordinator.emitUpdate();
    const completeCb = HomeInventoryCoordinator.onComplete;
    HomeInventoryCoordinator.onUpdate = () => {};
    HomeInventoryCoordinator.onComplete = () => {};

    if (notifyComplete) {
      completeCb();
    }
  }

  static stopForBackground(): void {
    HomeInventoryCoordinator.stop(true);
  }
}
