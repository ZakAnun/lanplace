import { ble } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { mergeScanResult } from '../common/BleAdvertParser';
import { ScannedDevice } from '../model/ScannedDevice';
import { SCAN_TIMEOUT_MS } from '../common/Constants';
import {
  BleScanStopOptions,
  BLE_SCAN_STOP_QUIET,
  BLE_SCAN_STOP_WITH_COMPLETE
} from './BleScanStopOptions';

export { BleScanStopOptions, BLE_SCAN_STOP_QUIET, BLE_SCAN_STOP_WITH_COMPLETE };

type ScanCallback = (devices: ScannedDevice[]) => void;
type ScanCompleteCallback = () => void;

export class BleScanService {
  private static scanning: boolean = false;
  private static deviceMap: Map<string, ScannedDevice> = new Map();
  private static timerId: number = -1;
  private static throttleId: number = -1;
  private static onUpdate: ScanCallback = () => {};
  private static onComplete: ScanCompleteCallback = () => {};

  private static emitUpdate(): void {
    const list = Array.from(BleScanService.deviceMap.values());
    list.sort((a, b) => b.rssi - a.rssi);
    BleScanService.onUpdate(list);
  }

  private static detachListener(): void {
    try {
      ble.off('BLEDeviceFind', BleScanService.onDeviceFind);
    } catch (_err) {
      // ignore
    }
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

  static start(onUpdate: ScanCallback, onComplete?: ScanCompleteCallback): boolean {
    if (BleScanService.scanning) {
      return false;
    }
    BleScanService.onUpdate = onUpdate;
    BleScanService.onComplete = onComplete ?? (() => {});
    BleScanService.deviceMap.clear();
    BleScanService.scanning = true;
    try {
      ble.on('BLEDeviceFind', BleScanService.onDeviceFind);
      const options: ble.ScanOptions = {
        interval: 0,
        dutyMode: ble.ScanDuty.SCAN_MODE_LOW_LATENCY
      };
      ble.startBLEScan(null, options);
      BleScanService.timerId = setTimeout(() => {
        BleScanService.stop({ emitUpdate: true, notifyComplete: true });
      }, SCAN_TIMEOUT_MS) as number;
      return true;
    } catch (err) {
      BleScanService.detachListener();
      BleScanService.scanning = false;
      BleScanService.onUpdate = () => {};
      BleScanService.onComplete = () => {};
      const e = err as BusinessError;
      throw new Error(`BLE scan failed: ${e.code} ${e.message}`);
    }
  }

  static stop(options?: BleScanStopOptions): void {
    if (!BleScanService.scanning) {
      return;
    }
    const emitUpdate = options?.emitUpdate !== false;
    const notifyComplete = options?.notifyComplete !== false;

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
      ble.stopBLEScan();
    } catch (_err) {
      // ignore
    }
    BleScanService.detachListener();

    const updateCb = BleScanService.onUpdate;
    const completeCb = BleScanService.onComplete;
    BleScanService.onUpdate = () => {};
    BleScanService.onComplete = () => {};

    if (emitUpdate) {
      const list = Array.from(BleScanService.deviceMap.values());
      list.sort((a, b) => b.rssi - a.rssi);
      updateCb(list);
    }
    if (notifyComplete) {
      completeCb();
    }
  }
}
