import { LogEvent, LogEventDomain } from './LogEvent';

export interface LogEventStore {
  append(event: LogEvent): void;
  query(deviceKey: string, domain: LogEventDomain): LogEvent[];
  exportText(deviceKey?: string): string;
  clear(): void;
}

export class LogEventBus {
  private static store: LogEventStore | null = null;

  static bindStore(store: LogEventStore): void {
    LogEventBus.store = store;
  }

  static append(event: LogEvent): void {
    const impl: LogEventStore | null = LogEventBus.store;
    if (impl !== null) {
      impl.append(event);
    }
  }

  static query(deviceKey: string, domain: LogEventDomain): LogEvent[] {
    const impl: LogEventStore | null = LogEventBus.store;
    if (impl === null) {
      return [];
    }
    return impl.query(deviceKey, domain);
  }

  static exportText(deviceKey?: string): string {
    const impl: LogEventStore | null = LogEventBus.store;
    if (impl === null) {
      return '';
    }
    return impl.exportText(deviceKey);
  }

  static clear(): void {
    const impl: LogEventStore | null = LogEventBus.store;
    if (impl !== null) {
      impl.clear();
    }
  }
}
