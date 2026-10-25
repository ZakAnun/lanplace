export const SCAN_TIMEOUT_MS: number = 30000;
export const PRIVACY_ACCEPTED_KEY: string = 'privacy_accepted_v2';
export const PREFS_NAME: string = 'bluescopes_prefs';
export const PRIVACY_POLICY_URL: string = 'https://zakanun.github.io/lanplace/legal/privacy-zh.html';

/**
 * 强制 Mock BLE（忽略是否真机）。模拟器上默认由 DeviceEnvironment.isSimulator() 自动开启 Mock。
 * 真机临时演示 Mock 时可改为 true。
 */
export const ENABLE_MOCK_BLE_SCAN: boolean = false;
