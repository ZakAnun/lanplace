import { LogEvent, LogEventDomain } from '../domain/LogEvent';

export const LOG_CAP: number = 500;

export class InMemoryLogStore {
  private readonly byDevice: Map<string, LogEvent[]> = new Map();

  append(event: LogEvent): void {
    let list: LogEvent[] | undefined = this.byDevice.get(event.deviceKey);
    if (list === undefined) {
      list = [];
      this.byDevice.set(event.deviceKey, list);
    }
    list.push(event);
    while (list.length > LOG_CAP) {
      list.shift();
    }
  }

  query(deviceKey: string, domain: LogEventDomain): LogEvent[] {
    const list: LogEvent[] | undefined = this.byDevice.get(deviceKey);
    if (list === undefined) {
      return [];
    }
    const matched: LogEvent[] = [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].domain === domain) {
        matched.push(list[i]);
      }
    }
    return matched;
  }

  exportText(deviceKey?: string): string {
    const lines: string[] = ['BlueScopes session log'];
    if (deviceKey !== undefined && deviceKey.length > 0) {
      lines.push(`deviceKey=${deviceKey}`);
      this.appendLines(lines, this.byDevice.get(deviceKey));
      return lines.join('\n');
    }
    const keys: string[] = [];
    this.byDevice.forEach((_list: LogEvent[], key: string) => {
      keys.push(key);
    });
    for (let i = 0; i < keys.length; i++) {
      this.appendLines(lines, this.byDevice.get(keys[i]));
    }
    return lines.join('\n');
  }

  clear(): void {
    this.byDevice.clear();
  }

  private appendLines(lines: string[], list: LogEvent[] | undefined): void {
    if (list === undefined) {
      return;
    }
    for (let i = 0; i < list.length; i++) {
      const event: LogEvent = list[i];
      lines.push(`${event.ts}\t${event.deviceKey}\t${event.domain}\t${event.type}\t${event.message}`);
    }
  }
}
