import { deviceInfo } from '@kit.BasicServicesKit';

export function isSimulatorProductHint(value: string): boolean {
  const hint = value.trim().toLowerCase();
  if (hint.length === 0) {
    return false;
  }
  return hint.includes('emulator') || hint.includes('simulator') || hint === 'qemu';
}

export class DeviceEnvironment {
  static isSimulator(): boolean {
    try {
      if (isSimulatorProductHint(deviceInfo.productModel ?? '')) {
        return true;
      }
      if (isSimulatorProductHint(deviceInfo.manufacture ?? '')) {
        return true;
      }
      if (isSimulatorProductHint(deviceInfo.hardwareModel ?? '')) {
        return true;
      }
      if (isSimulatorProductHint(deviceInfo.softwareModel ?? '')) {
        return true;
      }
      return false;
    } catch (_err) {
      return false;
    }
  }
}
