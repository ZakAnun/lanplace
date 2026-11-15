export type LogEventDomain = 'ble' | 'lan';

export interface LogEvent {
  ts: number;
  deviceKey: string;
  domain: LogEventDomain;
  type: string;
  message: string;
}
