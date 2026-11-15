export interface GattCharacteristicNode {
  serviceUuid: string;
  characteristicUuid: string;
  canRead: boolean;
  canWrite: boolean;
  canWriteNoResponse: boolean;
  canNotify: boolean;
  canIndicate: boolean;
}

export interface GattServiceNode {
  serviceUuid: string;
  characteristics: GattCharacteristicNode[];
}

export interface GattValueEvent {
  deviceId: string;
  serviceUuid: string;
  characteristicUuid: string;
  value: Uint8Array;
}

export type GattValueListener = (event: GattValueEvent) => void;
