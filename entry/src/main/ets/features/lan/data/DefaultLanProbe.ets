import { HTTP_BODY_PREVIEW_MAX, HttpHeadResult, TCP_PROBE_TIMEOUT_MS, TcpProbeResult } from '../domain/ProbeTypes';
import { LanProbeApi } from '../domain/LanProbeFacade';
import { HarmonyHttpTransport } from './HarmonyHttpTransport';
import { HarmonyTcpTransport } from './HarmonyTcpTransport';
import { httpHead, HttpGetTransport } from './HttpHeadProbe';
import { ProbeClock, SystemProbeClock, tcpProbe, TcpConnectTransport } from './TcpProbe';

export class DefaultLanProbe implements LanProbeApi {
  private readonly tcpTransport: TcpConnectTransport;
  private readonly httpTransport: HttpGetTransport;
  private readonly clock: ProbeClock;

  constructor(tcpTransport?: TcpConnectTransport, httpTransport?: HttpGetTransport, clock?: ProbeClock) {
    this.tcpTransport = tcpTransport !== undefined ? tcpTransport : new HarmonyTcpTransport();
    this.httpTransport = httpTransport !== undefined ? httpTransport : new HarmonyHttpTransport();
    this.clock = clock !== undefined ? clock : new SystemProbeClock();
  }

  tcpProbe(host: string, port: number, timeoutMs: number): Promise<TcpProbeResult> {
    const timeout: number = timeoutMs > 0 ? timeoutMs : TCP_PROBE_TIMEOUT_MS;
    return tcpProbe(host, port, timeout, this.tcpTransport, this.clock);
  }

  httpHead(url: string, maxBody: number): Promise<HttpHeadResult> {
    const cap: number = maxBody > 0 ? maxBody : HTTP_BODY_PREVIEW_MAX;
    return httpHead(url, cap, this.httpTransport);
  }
}
