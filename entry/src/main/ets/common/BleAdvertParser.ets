import { util } from '@kit.ArkTS';
import { DeviceLinkState, ScannedDevice } from '../model/ScannedDevice';

const AD_TYPE_FLAGS = 0x01;
const AD_TYPE_UUID16_INC = 0x02;
const AD_TYPE_UUID16_COMP = 0x03;
const AD_TYPE_UUID32_INC = 0x04;
const AD_TYPE_UUID32_COMP = 0x05;
const AD_TYPE_UUID128_INC = 0x06;
const AD_TYPE_UUID128_COMP = 0x07;
const AD_TYPE_LOCAL_NAME_SHORT = 0x08;
const AD_TYPE_LOCAL_NAME_COMPLETE = 0x09;
const AD_TYPE_TX_POWER = 0x0A;
const AD_TYPE_MANUFACTURER = 0xFF;

export interface ParsedAdvert {
  flags?: number;
  localName?: string;
  txPower?: number;
  serviceUuids: string[];
  manufacturerHex?: string;
  serviceDataHex?: string;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join(':');
}

function readInt8(byte: number): number {
  return byte > 127 ? byte - 256 : byte;
}

function parseUuid16(data: Uint8Array, offset: number, length: number, out: string[]): void {
  for (let i = 0; i + 1 < length; i += 2) {
    const uuid = `0000${data[offset + i + 1].toString(16).padStart(2, '0')}${data[offset + i].toString(16).padStart(2, '0')}-0000-1000-8000-00805f9b34fb`;
    out.push(uuid);
  }
}

function parseUuid32(data: Uint8Array, offset: number, length: number, out: string[]): void {
  for (let i = 0; i + 3 < length; i += 4) {
    const b0 = data[offset + i].toString(16).padStart(2, '0');
    const b1 = data[offset + i + 1].toString(16).padStart(2, '0');
    const b2 = data[offset + i + 2].toString(16).padStart(2, '0');
    const b3 = data[offset + i + 3].toString(16).padStart(2, '0');
    out.push(`${b3}${b2}${b1}${b0}-0000-1000-8000-00805f9b34fb`);
  }
}

function parseUuid128(data: Uint8Array, offset: number, length: number, out: string[]): void {
  for (let i = 0; i + 15 < length; i += 16) {
    const p = (idx: number): string => data[offset + i + idx].toString(16).padStart(2, '0');
    const uuid = `${p(15)}${p(14)}${p(13)}${p(12)}-${p(11)}${p(10)}-${p(9)}${p(8)}-${p(7)}${p(6)}-${p(5)}${p(4)}${p(3)}${p(2)}${p(1)}${p(0)}`;
    out.push(uuid);
  }
}

function decodeUtf8Name(data: Uint8Array, offset: number, length: number): string {
  if (length <= 0) {
    return '';
  }
  const slice = data.subarray(offset, offset + length);
  try {
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    return decoder.decodeWithStream(slice, { stream: false });
  } catch (_err) {
    let s = '';
    for (let i = 0; i < length; i++) {
      s += String.fromCharCode(data[offset + i]);
    }
    return s;
  }
}

export function parseAdvertData(data: ArrayBuffer): ParsedAdvert {
  const result: ParsedAdvert = { serviceUuids: [] };
  if (!data || data.byteLength === 0) {
    return result;
  }
  const adv = new Uint8Array(data);
  let pos = 0;
  while (pos < adv.length) {
    const length = adv[pos++];
    if (length === 0) {
      break;
    }
    if (pos >= adv.length) {
      break;
    }
    const type = adv[pos++];
    const payloadLen = length - 1;
    if (payloadLen < 0 || pos + payloadLen > adv.length) {
      break;
    }
    switch (type) {
      case AD_TYPE_FLAGS:
        if (payloadLen >= 1) {
          result.flags = adv[pos];
        }
        break;
      case AD_TYPE_LOCAL_NAME_SHORT:
      case AD_TYPE_LOCAL_NAME_COMPLETE:
        result.localName = decodeUtf8Name(adv, pos, payloadLen);
        break;
      case AD_TYPE_TX_POWER:
        if (payloadLen >= 1) {
          result.txPower = readInt8(adv[pos]);
        }
        break;
      case AD_TYPE_UUID16_INC:
      case AD_TYPE_UUID16_COMP:
        parseUuid16(adv, pos, payloadLen, result.serviceUuids);
        break;
      case AD_TYPE_UUID32_INC:
      case AD_TYPE_UUID32_COMP:
        parseUuid32(adv, pos, payloadLen, result.serviceUuids);
        break;
      case AD_TYPE_UUID128_INC:
      case AD_TYPE_UUID128_COMP:
        parseUuid128(adv, pos, payloadLen, result.serviceUuids);
        break;
      case AD_TYPE_MANUFACTURER:
        result.manufacturerHex = bytesToHex(adv.slice(pos, pos + payloadLen));
        break;
      default:
        if (type === 0x16 && payloadLen > 0) {
          result.serviceDataHex = bytesToHex(adv.slice(pos, pos + payloadLen));
        }
        break;
    }
    pos += payloadLen;
  }
  return result;
}

export function mergeScanResult(
  deviceId: string,
  deviceName: string,
  rssi: number,
  connectable: boolean,
  data: ArrayBuffer
): ScannedDevice {
  const parsed = parseAdvertData(data);
  const displayName = (deviceName && deviceName.length > 0)
    ? deviceName
    : (parsed.localName && parsed.localName.length > 0 ? parsed.localName : '未知设备');
  const connLabel = connectable ? '可连接' : '仅广播';
  const detailLine = `${deviceId} · ${rssi} dBm · ${connLabel}`;
  const parts: string[] = [];
  if (parsed.flags !== undefined) {
    parts.push(`Flags 0x${parsed.flags.toString(16)}`);
  }
  if (parsed.txPower !== undefined) {
    parts.push(`TX ${parsed.txPower} dBm`);
  }
  if (parsed.serviceUuids.length > 0) {
    parts.push(`UUID ${parsed.serviceUuids.slice(0, 2).join(', ')}`);
  }
  if (parsed.manufacturerHex) {
    parts.push(`Mfg ${parsed.manufacturerHex.substring(0, 20)}`);
  }
  if (parsed.serviceDataHex) {
    parts.push(`SvcData ${parsed.serviceDataHex.substring(0, 20)}`);
  }
  return {
    deviceId,
    displayName,
    rssi,
    connectable,
    detailLine,
    advertSummary: parts.join(' · '),
    linkState: connectable ? DeviceLinkState.Available : DeviceLinkState.Discovered
  };
}
