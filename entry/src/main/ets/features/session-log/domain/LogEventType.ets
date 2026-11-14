export class LogEventType {
  static readonly SCAN_START: string = 'SCAN_START';
  static readonly SCAN_STOP: string = 'SCAN_STOP';
  static readonly GATT_CONNECT: string = 'GATT_CONNECT';
  static readonly GATT_DISCONNECT: string = 'GATT_DISCONNECT';
  static readonly GATT_ERROR: string = 'GATT_ERROR';
  static readonly LAN_PROBE_TCP: string = 'LAN_PROBE_TCP';
  static readonly LAN_PROBE_HTTP: string = 'LAN_PROBE_HTTP';
  static readonly USER_EXPORT: string = 'USER_EXPORT';
}
