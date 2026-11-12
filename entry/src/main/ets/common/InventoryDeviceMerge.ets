import {
  HomeInventoryDevice,
  InventoryDeviceKind
} from '../model/HomeInventoryDevice';

export function bleInventoryKey(deviceId: string): string {
  return `ble:${deviceId}`;
}

export function selectionKeyIfStillPresent(selectedKey: string, devices: HomeInventoryDevice[]): string {
  if (selectedKey.length === 0) {
    return '';
  }
  for (let i = 0; i < devices.length; i++) {
    if (devices[i].deviceKey === selectedKey) {
      return selectedKey;
    }
  }
  return '';
}

/** 按正式扫描结果的 key 形态生成设备列表：ble:<id> / lan:host:<ip> */
export function syntheticInventoryFeed(bleCount: number, lanCount: number): HomeInventoryDevice[] {
  const list: HomeInventoryDevice[] = [];
  for (let i = 0; i < bleCount; i++) {
    list.push({
      deviceKey: bleInventoryKey(`aa:bb:cc:dd:ee:${i}`),
      kind: InventoryDeviceKind.Ble,
      displayName: `BLE ${i}`,
      detailLine: `${-40 - (i % 50)} dBm`,
      extraLine: '',
      rssi: -40 - (i % 50)
    });
  }
  for (let i = 0; i < lanCount; i++) {
    const host = `192.168.1.${(i % 250) + 1}`;
    list.push({
      deviceKey: `lan:host:${host}`,
      kind: InventoryDeviceKind.Lan,
      displayName: `LAN ${i}`,
      detailLine: `${host}:80`,
      extraLine: '_http._tcp',
      rssi: 0
    });
  }
  return list;
}

export function withRssiJitter(list: HomeInventoryDevice[], delta: number): HomeInventoryDevice[] {
  const next: HomeInventoryDevice[] = [];
  for (let i = 0; i < list.length; i++) {
    const d = list[i];
    next.push({
      deviceKey: d.deviceKey,
      kind: d.kind,
      displayName: d.displayName,
      detailLine: d.detailLine,
      extraLine: d.extraLine,
      rssi: d.rssi + delta
    });
  }
  return next;
}

export function withoutDeviceKey(list: HomeInventoryDevice[], dropKey: string): HomeInventoryDevice[] {
  const next: HomeInventoryDevice[] = [];
  for (let i = 0; i < list.length; i++) {
    if (list[i].deviceKey !== dropKey) {
      next.push(list[i]);
    }
  }
  return next;
}
