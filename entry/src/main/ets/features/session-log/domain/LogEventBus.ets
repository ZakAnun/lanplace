import { InMemoryLogStore } from '../data/InMemoryLogStore';
import { LogEvent, LogEventDomain } from './LogEvent';

export class LogEventBus {
  private static store: InMemoryLogStore = new InMemoryLogStore();

  static append(event: LogEvent): void {
    LogEventBus.store.append(event);
  }

  static query(deviceKey: string, domain: LogEventDomain): LogEvent[] {
    return LogEventBus.store.query(deviceKey, domain);
  }

  static exportText(deviceKey?: string): string {
    return LogEventBus.store.exportText(deviceKey);
  }

  static clear(): void {
    LogEventBus.store.clear();
  }
}
