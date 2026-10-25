import { common } from '@kit.AbilityKit';
import { mdns } from '@kit.NetworkKit';
import { DeviceEnvironment } from '../common/DeviceEnvironment';

export interface LanDiscoveredDevice {
  deviceKey: string;
  displayName: string;
  serviceTypes: string[];
  hostAddress: string;
  port: number;
}

type LanUpdateCallback = (devices: LanDiscoveredDevice[]) => void;

const LAN_SERVICE_TYPES: string[] = [
  '_hap._tcp',
  '_googlecast._tcp',
  '_airplay._tcp',
  '_ipp._tcp',
  '_http._tcp'
];

const MOCK_LAN: LanDiscoveredDevice[] = [
  {
    deviceKey: 'lan:host:192.168.1.20',
    displayName: '客厅电视 (Cast)',
    serviceTypes: ['_googlecast._tcp'],
    hostAddress: '192.168.1.20',
    port: 8009
  },
  {
    deviceKey: 'lan:host:192.168.1.30',
    displayName: '书房打印机',
    serviceTypes: ['_ipp._tcp'],
    hostAddress: '192.168.1.30',
    port: 631
  }
];

export class MdnsScanService {
  private static scanning: boolean = false;
  private static deviceMap: Map<string, LanDiscoveredDevice> = new Map();
  private static discoveries: mdns.DiscoveryService[] = [];
  private static onUpdate: LanUpdateCallback = () => {};

  static isScanning(): boolean {
    return MdnsScanService.scanning;
  }

  private static hostDeviceKey(host: string): string {
    return `lan:host:${host}`;
  }

  private static emitUpdate(): void {
    const list = Array.from(MdnsScanService.deviceMap.values());
    list.sort((a, b) => a.displayName.localeCompare(b.displayName));
    MdnsScanService.onUpdate(list);
  }

  private static mergeServiceType(types: string[], serviceType: string): string[] {
    for (let i = 0; i < types.length; i++) {
      if (types[i] === serviceType) {
        return types;
      }
    }
    const next = types.slice();
    next.push(serviceType);
    return next;
  }

  private static ingestResolvedService(serviceType: string, resolved: mdns.LocalServiceInfo): void {
    const name = resolved.serviceName ?? '未知设备';
    const host = resolved.host?.address ?? '';
    if (host.length === 0) {
      return;
    }
    const port = resolved.port ?? 0;
    const key = MdnsScanService.hostDeviceKey(host);
    const existing = MdnsScanService.deviceMap.get(key);
    if (existing !== undefined) {
      const displayName = name.length > existing.displayName.length ? name : existing.displayName;
      const serviceTypes = MdnsScanService.mergeServiceType(existing.serviceTypes, serviceType);
      const usePort = port > 0 ? port : existing.port;
      MdnsScanService.deviceMap.set(key, {
        deviceKey: key,
        displayName,
        serviceTypes,
        hostAddress: host,
        port: usePort
      });
    } else {
      MdnsScanService.deviceMap.set(key, {
        deviceKey: key,
        displayName: name,
        serviceTypes: [serviceType],
        hostAddress: host,
        port
      });
    }
    MdnsScanService.emitUpdate();
  }

  private static attachDiscovery(context: common.Context, serviceType: string): void {
    try {
      const discovery = mdns.createDiscoveryService(context, serviceType);
      discovery.on('serviceFound', (serviceInfo: mdns.LocalServiceInfo) => {
        if (!MdnsScanService.scanning) {
          return;
        }
        mdns.resolveLocalService(context, serviceInfo).then((resolved: mdns.LocalServiceInfo) => {
          if (!MdnsScanService.scanning) {
            return;
          }
          MdnsScanService.ingestResolvedService(serviceType, resolved);
        }).catch(() => {
          // resolve 超时或失败时忽略单条
        });
      });
      discovery.on('serviceLost', (serviceInfo: mdns.LocalServiceInfo) => {
        if (!MdnsScanService.scanning) {
          return;
        }
        const name = serviceInfo.serviceName ?? '';
        if (name.length === 0) {
          return;
        }
        let changed = false;
        MdnsScanService.deviceMap.forEach((entry: LanDiscoveredDevice, key: string) => {
          if (entry.displayName !== name) {
            return;
          }
          const nextTypes: string[] = [];
          for (let i = 0; i < entry.serviceTypes.length; i++) {
            if (entry.serviceTypes[i] !== serviceType) {
              nextTypes.push(entry.serviceTypes[i]);
            }
          }
          if (nextTypes.length === entry.serviceTypes.length) {
            return;
          }
          changed = true;
          if (nextTypes.length === 0) {
            MdnsScanService.deviceMap.delete(key);
          } else {
            MdnsScanService.deviceMap.set(key, {
              deviceKey: entry.deviceKey,
              displayName: entry.displayName,
              serviceTypes: nextTypes,
              hostAddress: entry.hostAddress,
              port: entry.port
            });
          }
        });
        if (changed) {
          MdnsScanService.emitUpdate();
        }
      });
      discovery.startSearchingMDNS();
      MdnsScanService.discoveries.push(discovery);
    } catch (_err) {
      // ignore unsupported service type on device
    }
  }

  static start(context: common.Context, onUpdate: LanUpdateCallback): boolean {
    if (MdnsScanService.scanning) {
      return false;
    }
    MdnsScanService.onUpdate = onUpdate;
    MdnsScanService.deviceMap.clear();
    MdnsScanService.discoveries = [];
    MdnsScanService.scanning = true;

    if (DeviceEnvironment.isSimulator()) {
      for (let i = 0; i < MOCK_LAN.length; i++) {
        MdnsScanService.deviceMap.set(MOCK_LAN[i].deviceKey, MOCK_LAN[i]);
      }
      MdnsScanService.emitUpdate();
      return true;
    }

    for (let i = 0; i < LAN_SERVICE_TYPES.length; i++) {
      MdnsScanService.attachDiscovery(context, LAN_SERVICE_TYPES[i]);
    }
    if (MdnsScanService.discoveries.length === 0) {
      MdnsScanService.scanning = false;
      MdnsScanService.onUpdate = () => {};
      return false;
    }
    return true;
  }

  static stop(): void {
    if (!MdnsScanService.scanning) {
      return;
    }
    MdnsScanService.scanning = false;
    for (let i = 0; i < MdnsScanService.discoveries.length; i++) {
      try {
        MdnsScanService.discoveries[i].stopSearchingMDNS();
      } catch (_err) {
        // ignore
      }
    }
    MdnsScanService.discoveries = [];
    MdnsScanService.onUpdate = () => {};
  }
}
