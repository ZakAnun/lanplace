import { describe, it, expect } from '@ohos/hypium';
import { LogEvent, LogEventDomain } from '../main/ets/features/session-log/domain/LogEvent';
import { LogEventBus } from '../main/ets/features/session-log/domain/LogEventBus';
import { LogEventType } from '../main/ets/features/session-log/domain/LogEventType';
import { InMemoryLogStore } from '../main/ets/features/session-log/data/InMemoryLogStore';
import { LanProbeApi, LanProbeFacade } from '../main/ets/features/lan/domain/LanProbeFacade';
import {
  HostPort,
  HttpHeadResult,
  NATIVE_TCP_CONNECT_TIMEOUT_MS,
  TCP_PROBE_TIMEOUT_MS,
  TcpProbeResult,
  formatLanExtraLine,
  httpUrlForHostPort,
  parseHostPort,
  printableTxtBytes
} from '../main/ets/features/lan/domain/ProbeTypes';
import {
  ProbeClock,
  TcpConnectTransport,
  tcpProbe
} from '../main/ets/features/lan/data/TcpProbe';

type ClockFire = () => void;

class ManualProbeClock implements ProbeClock {
  lastDelayMs: number = -1;
  private pending: ClockFire | null = null;

  schedule(delayMs: number, onFire: ClockFire): number {
    this.lastDelayMs = delayMs;
    this.pending = onFire;
    return 1;
  }

  cancel(_timerId: number): void {
    this.pending = null;
  }

  fire(): void {
    const pending: ClockFire | null = this.pending;
    if (pending === null) {
      return;
    }
    this.pending = null;
    pending();
  }
}

class ImmediateTcpTransport implements TcpConnectTransport {
  readonly outcome: string;
  aborted: boolean = false;

  constructor(outcome: string) {
    this.outcome = outcome;
  }

  connect(_host: string, _port: number, _timeoutMs: number): Promise<void> {
    if (this.outcome === 'open') {
      return Promise.resolve();
    }
    return Promise.reject(new Error('connection refused'));
  }

  abort(): void {
    this.aborted = true;
  }
}

class FakeLanProbe implements LanProbeApi {
  tcpResult: TcpProbeResult = 'open';
  httpResult: HttpHeadResult = {
    status: 200,
    contentType: 'text/plain',
    bodyPreview: 'hello'
  };

  tcpProbe(_host: string, _port: number, _timeoutMs: number): Promise<TcpProbeResult> {
    return Promise.resolve(this.tcpResult);
  }

  httpHead(_url: string, _maxBody: number): Promise<HttpHeadResult> {
    return Promise.resolve(this.httpResult);
  }
}

class HangTcpTransport implements TcpConnectTransport {
  aborted: boolean = false;
  seenTimeoutMs: number = -1;

  connect(_host: string, _port: number, timeoutMs: number): Promise<void> {
    this.seenTimeoutMs = timeoutMs;
    return new Promise<void>((_resolve: () => void): void => {
    });
  }

  abort(): void {
    this.aborted = true;
  }
}

class NativeTimeoutTcpTransport implements TcpConnectTransport {
  aborted: boolean = false;

  connect(_host: string, _port: number, _timeoutMs: number): Promise<void> {
    return Promise.reject(new Error('Socket timeout'));
  }

  abort(): void {
    this.aborted = true;
  }
}

export default function tcpProbeTest() {
  describe('TcpProbe', () => {
    it('defaultTimeoutIs3000Ms', 0, () => {
      expect(TCP_PROBE_TIMEOUT_MS).assertEqual(3000);
    });

    it('parseHostPortSplitsIpv4DetailLine', 0, () => {
      const parsed: HostPort | null = parseHostPort('192.168.1.20:8009');
      expect(parsed !== null).assertTrue();
      if (parsed !== null) {
        expect(parsed.host).assertEqual('192.168.1.20');
        expect(parsed.port).assertEqual(8009);
      }
    });

    it('parseHostPortRejectsEmptyOrInvalid', 0, () => {
      expect(parseHostPort('')).assertNull();
      expect(parseHostPort('192.168.1.20')).assertNull();
      expect(parseHostPort(':80')).assertNull();
      expect(parseHostPort('192.168.1.20:0')).assertNull();
    });

    it('httpUrlForHostPortUsesHttpScheme', 0, () => {
      expect(httpUrlForHostPort('192.168.1.20', 8009)).assertEqual('http://192.168.1.20:8009/');
    });

    it('formatLanExtraLineKeepsServiceTypesAndAppendsTxt', 0, () => {
      expect(formatLanExtraLine(['_http._tcp'], '')).assertEqual('_http._tcp');
      expect(formatLanExtraLine(['_http._tcp', '_ipp._tcp'], 'fn=Printer')).assertEqual(
        '_http._tcp · _ipp._tcp · fn=Printer');
    });

    it('formatLanExtraLineKeepsUtf8TxtValue', 0, () => {
      const bytes: Array<number> = [0x00, 0xE5, 0xAE, 0xA2, 0x0A, 0xE5, 0x8E, 0x85];
      const fn: string = printableTxtBytes(bytes);
      expect(fn).assertEqual('客厅');
      expect(formatLanExtraLine(['_googlecast._tcp'], `fn=${fn}`)).assertEqual(
        '_googlecast._tcp · fn=客厅');
    });

    it('resolvesOpenWhenTransportConnects', 0, async (): Promise<void> => {
      const transport: ImmediateTcpTransport = new ImmediateTcpTransport('open');
      const result = await tcpProbe('192.168.1.20', 8009, 3000, transport);
      expect(result).assertEqual('open');
    });

    it('resolvesClosedWhenTransportRejects', 0, async (): Promise<void> => {
      const transport: ImmediateTcpTransport = new ImmediateTcpTransport('closed');
      const result = await tcpProbe('192.168.1.20', 8009, 3000, transport);
      expect(result).assertEqual('closed');
    });

    it('resolvesTimeoutWhenClockFiresFirst', 0, async (): Promise<void> => {
      const clock: ManualProbeClock = new ManualProbeClock();
      const transport: HangTcpTransport = new HangTcpTransport();
      const pending = tcpProbe('192.168.1.20', 80, 50, transport, clock);
      expect(clock.lastDelayMs).assertEqual(50);
      expect(transport.seenTimeoutMs).assertEqual(NATIVE_TCP_CONNECT_TIMEOUT_MS);
      clock.fire();
      const result = await pending;
      expect(result).assertEqual('timeout');
      expect(transport.aborted).assertTrue();
    });

    it('mapsNativeTimeoutClosedAndClockTimeoutSeparately', 0, async (): Promise<void> => {
      const nativeTimeout: TcpProbeResult = await tcpProbe(
        '192.168.1.20', 80, 3000, new NativeTimeoutTcpTransport());
      expect(nativeTimeout).assertEqual('timeout');

      const closed: TcpProbeResult = await tcpProbe(
        '192.168.1.20', 8009, 3000, new ImmediateTcpTransport('closed'));
      expect(closed).assertEqual('closed');

      const clock: ManualProbeClock = new ManualProbeClock();
      const hang: HangTcpTransport = new HangTcpTransport();
      const pending = tcpProbe('192.168.1.20', 80, 50, hang, clock);
      clock.fire();
      const clockTimeout: TcpProbeResult = await pending;
      expect(clockTimeout).assertEqual('timeout');
      expect(hang.aborted).assertTrue();
    });

    it('tcpProbeForDeviceAppendsLanLog', 0, async (): Promise<void> => {
      const domainLan: LogEventDomain = 'lan';
      LogEventBus.bindStore(new InMemoryLogStore());
      LanProbeFacade.bindFacade(new FakeLanProbe());
      const result: TcpProbeResult = await LanProbeFacade.tcpProbeForDevice('lan:host:1', '192.168.1.20', 8009);
      expect(result).assertEqual('open');
      const logs: LogEvent[] = LogEventBus.query('lan:host:1', domainLan);
      expect(logs.length).assertEqual(1);
      expect(logs[0].type).assertEqual(LogEventType.LAN_PROBE_TCP);
      expect(logs[0].message).assertEqual('192.168.1.20:8009 open');
      LanProbeFacade.resetFacade();
    });

    it('httpHeadForDeviceAppendsLanLog', 0, async (): Promise<void> => {
      const domainLan: LogEventDomain = 'lan';
      LogEventBus.bindStore(new InMemoryLogStore());
      LanProbeFacade.bindFacade(new FakeLanProbe());
      const result: HttpHeadResult = await LanProbeFacade.httpHeadForDevice('lan:host:1', 'http://192.168.1.20:8009/');
      expect(result.status).assertEqual(200);
      const logs: LogEvent[] = LogEventBus.query('lan:host:1', domainLan);
      expect(logs.length).assertEqual(1);
      expect(logs[0].type).assertEqual(LogEventType.LAN_PROBE_HTTP);
      expect(logs[0].message).assertContain('200');
      expect(logs[0].message).assertContain('text/plain');
      expect(logs[0].message).assertContain('hello');
      LanProbeFacade.resetFacade();
    });
  });
}
