import { wifiManager } from '@kit.ConnectivityKit';

export class WifiNetworkHelper {
  static async linkedSsid(): Promise<string> {
    try {
      const info = await wifiManager.getLinkedInfo();
      if (info === null || info.connState === undefined) {
        return '';
      }
      const ssid = info.ssid ?? '';
      return ssid.trim();
    } catch (_err) {
      return '';
    }
  }

  static async isWifiConnected(): Promise<boolean> {
    const ssid = await WifiNetworkHelper.linkedSsid();
    return ssid.length > 0;
  }
}
