import { wifiManager } from '@kit.ConnectivityKit';

export class WifiNetworkHelper {
  private static isUsableSsid(ssid: string): boolean {
    const trimmed = ssid.trim();
    if (trimmed.length === 0) {
      return false;
    }
    const lower = trimmed.toLowerCase();
    if (lower === '<unknown ssid>' || lower === 'unknown ssid') {
      return false;
    }
    return true;
  }

  /** 官方 isConnected：是否已连接 WLAN，不依赖 SSID 是否可读 */
  static isWifiLinked(): boolean {
    try {
      return wifiManager.isConnected();
    } catch (_err) {
      return false;
    }
  }

  static async linkedSsid(): Promise<string> {
    if (!WifiNetworkHelper.isWifiLinked()) {
      return '';
    }
    try {
      const info: wifiManager.WifiLinkedInfo = await wifiManager.getLinkedInfo();
      if (info.connState !== wifiManager.ConnState.CONNECTED) {
        return '';
      }
      const ssid = info.ssid;
      if (!WifiNetworkHelper.isUsableSsid(ssid)) {
        return '';
      }
      return ssid.trim();
    } catch (_err) {
      return '';
    }
  }

  static async isWifiConnected(): Promise<boolean> {
    return WifiNetworkHelper.isWifiLinked();
  }
}
