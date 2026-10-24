import { ENABLE_MOCK_BLE_SCAN } from '../common/Constants';
import { DeviceEnvironment } from '../common/DeviceEnvironment';
import { ScannedDevice } from '../model/ScannedDevice';
import { BleScanService, BleScanStopOptions } from './BleScanService';
import { MockBleScanService } from './MockBleScanService';

type ScanCallback = (devices: ScannedDevice[]) => void;
type ScanCompleteCallback = () => void;

export class BleScanCoordinator {
  static useMockScan(): boolean {
    return ENABLE_MOCK_BLE_SCAN || DeviceEnvironment.isSimulator();
  }

  static isScanning(): boolean {
    return BleScanCoordinator.useMockScan()
      ? MockBleScanService.isScanning()
      : BleScanService.isScanning();
  }

  static start(onUpdate: ScanCallback, onComplete?: ScanCompleteCallback): boolean {
    if (BleScanCoordinator.useMockScan()) {
      return MockBleScanService.start(onUpdate, onComplete);
    }
    return BleScanService.start(onUpdate, onComplete);
  }

  static stop(options?: BleScanStopOptions): void {
    if (BleScanCoordinator.useMockScan()) {
      MockBleScanService.stop(options);
      return;
    }
    BleScanService.stop(options);
  }
}
