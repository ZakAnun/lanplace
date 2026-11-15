import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { LogEvent, LogEventDomain } from '../main/ets/features/session-log/domain/LogEvent';
import { LogEventType } from '../main/ets/features/session-log/domain/LogEventType';
import { LogEventBus } from '../main/ets/features/session-log/domain/LogEventBus';
import {
  buildLogSharePayload,
  LOG_SHARE_PLAIN_TEXT,
  LOG_SHARE_TITLE,
  LogSharePayload
} from '../main/ets/features/session-log/domain/LogSharePayload';
import { InMemoryLogStore, LOG_CAP } from '../main/ets/features/session-log/data/InMemoryLogStore';

function logEvent(
  deviceKey: string,
  domain: LogEventDomain,
  type: string,
  message: string,
  ts: number
): LogEvent {
  const event: LogEvent = {
    ts: ts,
    deviceKey: deviceKey,
    domain: domain,
    type: type,
    message: message
  };
  return event;
}

export default function logEventBusTest() {
  describe('LogEventBus', () => {
    beforeEach(() => {
      LogEventBus.bindStore(new InMemoryLogStore());
    });

    it('usesBoundStoreForAppendAndQuery', 0, () => {
      const domainBle: LogEventDomain = 'ble';
      const store: InMemoryLogStore = new InMemoryLogStore();
      LogEventBus.bindStore(store);
      LogEventBus.append(logEvent('ble:bind', domainBle, LogEventType.GATT_CONNECT, 'bound', 1));
      expect(store.query('ble:bind', domainBle).length).assertEqual(1);
      expect(LogEventBus.query('ble:bind', domainBle).length).assertEqual(1);
      expect(LogEventBus.query('ble:bind', domainBle)[0].message).assertEqual('bound');
    });

    it('queryReturnsOnlyMatchingDeviceKeyAndDomain', 0, () => {
      const domainBle: LogEventDomain = 'ble';
      const domainLan: LogEventDomain = 'lan';
      LogEventBus.append(logEvent('ble:1', domainBle, LogEventType.GATT_CONNECT, 'connected', 1000));
      LogEventBus.append(logEvent('ble:1', domainLan, LogEventType.LAN_PROBE_TCP, 'open', 1001));
      LogEventBus.append(logEvent('ble:2', domainBle, LogEventType.GATT_CONNECT, 'other', 1002));
      const result: LogEvent[] = LogEventBus.query('ble:1', domainBle);
      expect(result.length).assertEqual(1);
      expect(result[0].deviceKey).assertEqual('ble:1');
      expect(result[0].domain).assertEqual(domainBle);
      expect(result[0].message).assertEqual('connected');
    });

    it('queryReturnsEmptyWhenNoMatch', 0, () => {
      const domainBle: LogEventDomain = 'ble';
      LogEventBus.append(logEvent('ble:1', domainBle, LogEventType.GATT_CONNECT, 'connected', 1));
      expect(LogEventBus.query('ble:missing', domainBle).length).assertEqual(0);
    });

    it('ringBufferDropsOldestPerDevice', 0, () => {
      const domainBle: LogEventDomain = 'ble';
      expect(LOG_CAP).assertEqual(500);
      for (let i = 0; i < LOG_CAP + 3; i++) {
        LogEventBus.append(logEvent('ble:cap', domainBle, LogEventType.GATT_CONNECT, `m${i}`, i));
      }
      const result: LogEvent[] = LogEventBus.query('ble:cap', domainBle);
      expect(result.length).assertEqual(LOG_CAP);
      expect(result[0].message).assertEqual('m3');
      expect(result[result.length - 1].message).assertEqual(`m${LOG_CAP + 2}`);
    });

    it('ringCapIsPerDeviceNotPerDomain', 0, () => {
      const domainBle: LogEventDomain = 'ble';
      const domainLan: LogEventDomain = 'lan';
      for (let i = 0; i < LOG_CAP; i++) {
        LogEventBus.append(logEvent('dev:mix', domainBle, LogEventType.GATT_CONNECT, `b${i}`, i));
      }
      LogEventBus.append(logEvent('dev:mix', domainLan, LogEventType.LAN_PROBE_TCP, 'lan-last', LOG_CAP));
      expect(LogEventBus.query('dev:mix', domainBle).length).assertEqual(LOG_CAP - 1);
      const lan: LogEvent[] = LogEventBus.query('dev:mix', domainLan);
      expect(lan.length).assertEqual(1);
      expect(lan[0].message).assertEqual('lan-last');
    });

    it('exportTextForDeviceOmitsOtherDevices', 0, () => {
      const domainBle: LogEventDomain = 'ble';
      const domainLan: LogEventDomain = 'lan';
      LogEventBus.append(logEvent('ble:1', domainBle, LogEventType.GATT_CONNECT, 'alpha', 10));
      LogEventBus.append(logEvent('lan:2', domainLan, LogEventType.LAN_PROBE_HTTP, 'beta', 11));
      const dump: string = LogEventBus.exportText('ble:1');
      expect(dump).assertContain('ble:1');
      expect(dump).assertContain(LogEventType.GATT_CONNECT);
      expect(dump).assertContain('alpha');
      expect(dump.indexOf('lan:2') < 0).assertTrue();
      expect(dump.indexOf('beta') < 0).assertTrue();
    });

    it('exportTextWithoutDeviceKeyDumpsAll', 0, () => {
      const domainBle: LogEventDomain = 'ble';
      const domainLan: LogEventDomain = 'lan';
      LogEventBus.append(logEvent('ble:1', domainBle, LogEventType.SCAN_START, 'scan', 20));
      LogEventBus.append(logEvent('lan:2', domainLan, LogEventType.LAN_PROBE_TCP, 'probe', 21));
      const dump: string = LogEventBus.exportText();
      expect(dump).assertContain('ble:1');
      expect(dump).assertContain('scan');
      expect(dump).assertContain('lan:2');
      expect(dump).assertContain('probe');
    });

    it('sharePayloadPutsExportTextInContent', 0, () => {
      const domainBle: LogEventDomain = 'ble';
      LogEventBus.append(logEvent('ble:1', domainBle, LogEventType.GATT_CONNECT, 'alpha', 10));
      const dump: string = LogEventBus.exportText('ble:1');
      const payload: LogSharePayload = buildLogSharePayload(dump);
      expect(payload.content).assertEqual(dump);
      expect(payload.content).assertContain('alpha');
      expect(payload.content).assertContain('ble:1');
      expect(payload.utd).assertEqual(LOG_SHARE_PLAIN_TEXT);
      expect(payload.title).assertEqual(LOG_SHARE_TITLE);
      expect(payload.title === payload.content).assertFalse();
    });
  });
}
