import { DeviceLinkState, ScannedDevice } from '../model/ScannedDevice';
import { SCAN_TIMEOUT_MS } from '../common/Constants';
import { BLE_SCAN_STOP_WITH_COMPLETE, BleScanStopOptions } from './BleScanStopOptions';

type ScanCallback = (devices: ScannedDevice[]) => void;
type ScanCompleteCallback = () => void;

interface MockTemplate {
  deviceId: string;
  displayName: string;
  rssi: number;
  connectable: boolean;
  advertSummary: string;
}

const MOCK_CATALOG: MockTemplate[] = [
  {
    deviceId: 'AA:BB:CC:01:02:03',
    displayName: '客厅温湿度计',
    rssi: -48,
    connectable: true,
    advertSummary: 'UUID 0000180a-0000-1000-8000-00805f9b34fb · TX -4 dBm'
  },
  {
    deviceId: 'AA:BB:CC:11:22:33',
    displayName: 'Mi Band Demo',
    rssi: -62,
    connectable: true,
    advertSummary: 'Flags 0x6 · Mfg 57:01:…'
  },
  {
    deviceId: 'AA:BB:CC:44:55:66',
    displayName: 'Beacon-Gateway',
    rssi: -71,
    connectable: false,
    advertSummary: '仅广播 · SvcData 09:ff:…'
  },
  {
    deviceId: 'AA:BB:CC:77:88:99',
    displayName: '未知设备',
    rssi: -55,
    connectable: true,
    advertSummary: 'UUID 0000fff0-0000-1000-8000-00805f9b34fb'
  },
  {
    deviceId: 'AA:BB:CC:DE:AD:00',
    displayName: '键盘 K380',
    rssi: -58,
    connectable: true,
    advertSummary: 'Flags 0x4 · TX -8 dBm'
  }
];

export class MockBleScanService {
  private static scanning: boolean = false;
  private static deviceMap: Map<string, ScannedDevice> = new Map();
  private static endTimerId: number = -1;
  private static revealIntervalId: number = -1;
  private static rssiIntervalId: number = -1;
  private static onUpdate: ScanCallback = () => {};
  private static onComplete: ScanCompleteCallback = () => {};
  private static revealIndex: number = 0;

  static isScanning(): boolean {
    return MockBleScanService.scanning;
  }

  private static emitUpdate(): void {
    const list = Array.from(MockBleScanService.deviceMap.values());
    list.sort((a, b) => b.rssi - a.rssi);
    MockBleScanService.onUpdate(list);
  }

  private static clearTimers(): void {
    if (MockBleScanService.endTimerId >= 0) {
      clearTimeout(MockBleScanService.endTimerId);
      MockBleScanService.endTimerId = -1;
    }
    if (MockBleScanService.revealIntervalId >= 0) {
      clearInterval(MockBleScanService.revealIntervalId);
      MockBleScanService.revealIntervalId = -1;
    }
    if (MockBleScanService.rssiIntervalId >= 0) {
      clearInterval(MockBleScanService.rssiIntervalId);
      MockBleScanService.rssiIntervalId = -1;
    }
  }

  private static toDevice(t: MockTemplate, rssi: number): ScannedDevice {
    const connLabel = t.connectable ? '可连接' : '仅广播';
    return {
      deviceId: t.deviceId,
      displayName: t.displayName,
      rssi,
      connectable: t.connectable,
      detailLine: `${t.deviceId} · ${rssi} dBm · ${connLabel}`,
      advertSummary: t.advertSummary,
      linkState: DeviceLinkState.Discovered
    };
  }

  private static revealNextDevice(): void {
    if (MockBleScanService.revealIndex >= MOCK_CATALOG.length) {
      return;
    }
    const t = MOCK_CATALOG[MockBleScanService.revealIndex];
    MockBleScanService.revealIndex++;
    const dev = MockBleScanService.toDevice(t, t.rssi);
    MockBleScanService.deviceMap.set(t.deviceId, dev);
    MockBleScanService.emitUpdate();
  }

  static start(onUpdate: ScanCallback, onComplete?: ScanCompleteCallback): boolean {
    if (MockBleScanService.scanning) {
      return false;
    }
    MockBleScanService.onUpdate = onUpdate;
    MockBleScanService.onComplete = onComplete ?? (() => {});
    MockBleScanService.deviceMap.clear();
    MockBleScanService.revealIndex = 0;
    MockBleScanService.scanning = true;

    MockBleScanService.revealNextDevice();
    MockBleScanService.revealIntervalId = setInterval(() => {
      MockBleScanService.revealNextDevice();
    }, 900) as number;

    MockBleScanService.rssiIntervalId = setInterval(() => {
      MockBleScanService.deviceMap.forEach((d, id) => {
        const jitter = Math.floor(Math.random() * 5) - 2;
        const rssi = Math.min(-40, Math.max(-85, d.rssi + jitter));
        const connLabel = d.connectable ? '可连接' : '仅广播';
        MockBleScanService.deviceMap.set(id, {
          deviceId: d.deviceId,
          displayName: d.displayName,
          rssi,
          connectable: d.connectable,
          detailLine: `${d.deviceId} · ${rssi} dBm · ${connLabel}`,
          advertSummary: d.advertSummary,
          linkState: d.linkState
        });
      });
      MockBleScanService.emitUpdate();
    }, 1500) as number;

    MockBleScanService.endTimerId = setTimeout(() => {
      MockBleScanService.stop(BLE_SCAN_STOP_WITH_COMPLETE);
    }, SCAN_TIMEOUT_MS) as number;

    return true;
  }

  static stop(options?: BleScanStopOptions): void {
    if (!MockBleScanService.scanning) {
      return;
    }
    const emitUpdate = options?.emitUpdate !== false;
    const notifyComplete = options?.notifyComplete !== false;

    MockBleScanService.scanning = false;
    MockBleScanService.clearTimers();

    const updateCb = MockBleScanService.onUpdate;
    const completeCb = MockBleScanService.onComplete;
    MockBleScanService.onUpdate = () => {};
    MockBleScanService.onComplete = () => {};

    if (emitUpdate) {
      const list = Array.from(MockBleScanService.deviceMap.values());
      list.sort((a, b) => b.rssi - a.rssi);
      updateCb(list);
    }
    if (notifyComplete) {
      completeCb();
    }
  }
}
