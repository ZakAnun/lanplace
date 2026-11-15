import { GattServiceNode } from './GattProfile';
import { GattSessionPhase } from './GattSessionPhase';

export const GATT_MAX_WRITE_QUEUE: number = 1;

export interface BleGattSession {
  deviceId: string;
  phase: GattSessionPhase;
  mtu?: number;
  services?: string[];
  profile?: GattServiceNode[];
}
