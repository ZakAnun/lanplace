import { ble } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { mergeScanResult } from '../common/BleAdvertParser';
import { ScannedDevice } from '../model/ScannedDevice';
import { SCAN_TIMEOUT_MS } from '../common/Constants';

type ScanCallback = (devices: ScannedDevice[]) => void;

export class BleScanService {
  private static scanning: boolean = false;
  private static deviceMap: Map<string, ScannedDevice> = new Map();
  private static timerId: number = -1;
  private static throttleId: number = -1;
  private static onUpdate: ScanCallback = () => {};

  private static emitUpdate(): void {
    const list = Array.from(BleScanService.deviceMap.values());
    list.sort((a, b) => b.rssi - a.rssi);
    BleScanService.onUpdate(list);
  }

  private static onDeviceFind = (results: Array<ble.ScanResult>): void => {
    for (const item of results) {
      const merged = mergeScanResult(
        item.deviceId,
        item.deviceName ?? '',
        item.rssi,
        item.connectable,
        item.data
      );
      BleScanService.deviceMap.set(item.deviceId, merged);
    }
    if (BleScanService.throttleId >= 0) {
      return;
    }
    BleScanService.throttleId = setTimeout(() => {
      BleScanService.throttleId = -1;
      BleScanService.emitUpdate();
    }, 400) as number;
  };

  static isScanning(): boolean {
    return BleScanService.scanning;
  }

  static start(onUpdate: ScanCallback): void {
    if (BleScanService.scanning) {
      return;
    }
    BleScanService.onUpdate = onUpdate;
    BleScanService.deviceMap.clear();
    BleScanService.scanning = true;
    try {
      ble.on('BLEDeviceFind', BleScanService.onDeviceFind);
      const options: ble.ScanOptions = {
        interval: 0,
        dutyMode: ble.ScanDuty.SCAN_MODE_LOW_LATENCY
      };
      ble.startBLEScan([], options);
      BleScanService.timerId = setTimeout(() => {
        BleScanService.stop();
        BleScanService.emitUpdate();
      }, SCAN_TIMEOUT_MS) as number;
    } catch (err) {
      BleScanService.scanning = false;
      const e = err as BusinessError;
      throw new Error(`BLE scan failed: ${e.code} ${e.message}`);
    }
  }

  static stop(): void {
    if (!BleScanService.scanning) {
      return;
    }
    BleScanService.scanning = false;
    if (BleScanService.timerId >= 0) {
      clearTimeout(BleScanService.timerId);
      BleScanService.timerId = -1;
    }
    if (BleScanService.throttleId >= 0) {
      clearTimeout(BleScanService.throttleId);
      BleScanService.throttleId = -1;
    }
    try {
      ble.off('BLEDeviceFind', BleScanService.onDeviceFind);
      ble.stopBLEScan();
    } catch (_err) {
      // ignore stop errors
    }
    BleScanService.emitUpdate();
  }
}
