export interface ScanFilter {
  serviceUuid?: string;
  manufacturerId?: string;
  connectableOnly: boolean;
}

export interface ScanFilterTarget {
  connectable: boolean;
  advertServiceUuids: string[];
  advertManufacturerHex: string;
}

function isFilterTextSet(value?: string): boolean {
  if (value === undefined) {
    return false;
  }
  return value.trim().length > 0;
}

function normalizeHexToken(value: string): string {
  let out: string = '';
  for (let i = 0; i < value.length; i++) {
    const ch: string = value.charAt(i);
    if (ch !== ':' && ch !== '-' && ch !== ' ') {
      out += ch.toLowerCase();
    }
  }
  return out;
}

function matchesServiceUuid(device: ScanFilterTarget, serviceUuid: string): boolean {
  const want: string = normalizeHexToken(serviceUuid);
  if (want.length === 0) {
    return true;
  }
  for (let i = 0; i < device.advertServiceUuids.length; i++) {
    const have: string = normalizeHexToken(device.advertServiceUuids[i]);
    if (have.indexOf(want) >= 0) {
      return true;
    }
  }
  return false;
}

function matchesManufacturerId(device: ScanFilterTarget, manufacturerId: string): boolean {
  const want: string = normalizeHexToken(manufacturerId);
  if (want.length === 0) {
    return true;
  }
  const have: string = normalizeHexToken(device.advertManufacturerHex);
  return have.indexOf(want) >= 0;
}

export function scanFilterTargetOf(
  connectable: boolean,
  advertServiceUuids: string[],
  advertManufacturerHex: string
): ScanFilterTarget {
  const target: ScanFilterTarget = {
    connectable: connectable,
    advertServiceUuids: advertServiceUuids,
    advertManufacturerHex: advertManufacturerHex
  };
  return target;
}

export function defaultScanFilter(): ScanFilter {
  const filter: ScanFilter = {
    serviceUuid: '',
    manufacturerId: '',
    connectableOnly: false
  };
  return filter;
}

export function scanFilterIsActive(filter: ScanFilter): boolean {
  return isFilterTextSet(filter.serviceUuid)
    || isFilterTextSet(filter.manufacturerId)
    || filter.connectableOnly;
}

export function matchesFilter(device: ScanFilterTarget, filter: ScanFilter): boolean {
  if (filter.connectableOnly && !device.connectable) {
    return false;
  }
  const uuidText: string = filter.serviceUuid !== undefined ? filter.serviceUuid : '';
  if (isFilterTextSet(uuidText) && !matchesServiceUuid(device, uuidText)) {
    return false;
  }
  const mfgText: string = filter.manufacturerId !== undefined ? filter.manufacturerId : '';
  if (isFilterTextSet(mfgText) && !matchesManufacturerId(device, mfgText)) {
    return false;
  }
  return true;
}

export class ScanFilterHolder {
  private static value: ScanFilter = defaultScanFilter();

  static current(): ScanFilter {
    const src: ScanFilter = ScanFilterHolder.value;
    const copy: ScanFilter = {
      serviceUuid: src.serviceUuid,
      manufacturerId: src.manufacturerId,
      connectableOnly: src.connectableOnly
    };
    return copy;
  }

  static set(filter: ScanFilter): void {
    const uuid: string = filter.serviceUuid !== undefined ? filter.serviceUuid : '';
    const mfg: string = filter.manufacturerId !== undefined ? filter.manufacturerId : '';
    ScanFilterHolder.value = {
      serviceUuid: uuid,
      manufacturerId: mfg,
      connectableOnly: filter.connectableOnly
    };
  }
}
