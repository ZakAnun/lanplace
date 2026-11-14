import { WorkbenchTabId } from '../../workbench/domain/WorkbenchTabPolicy';

export interface DeviceWorkbenchParams {
  deviceKey: string;
  initialTab?: WorkbenchTabId;
}

export function parseBleDeviceId(deviceKey: string): string | undefined {
  const prefix = 'ble:';
  if (deviceKey.indexOf(prefix) !== 0) {
    return undefined;
  }
  const id = deviceKey.substring(prefix.length);
  return id.length > 0 ? id : undefined;
}
