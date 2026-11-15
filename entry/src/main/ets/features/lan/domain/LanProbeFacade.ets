import { LogEvent, LogEventDomain } from '../../session-log/domain/LogEvent';
import { LogEventBus } from '../../session-log/domain/LogEventBus';
import { LogEventType } from '../../session-log/domain/LogEventType';
import {
  HTTP_BODY_PREVIEW_MAX,
  HttpHeadResult,
  TCP_PROBE_TIMEOUT_MS,
  TcpProbeResult
} from './ProbeTypes';

export interface LanProbeApi {
  tcpProbe(host: string, port: number, timeoutMs: number): Promise<TcpProbeResult>;
  httpHead(url: string, maxBody: number): Promise<HttpHeadResult>;
}

export class LanProbeFacade {
  private static impl: LanProbeApi | null = null;

  static bindFacade(impl: LanProbeApi): void {
    LanProbeFacade.impl = impl;
  }

  static resetFacade(): void {
    LanProbeFacade.impl = null;
  }

  static tcpProbe(host: string, port: number, timeoutMs: number = TCP_PROBE_TIMEOUT_MS): Promise<TcpProbeResult> {
    const bound: LanProbeApi | null = LanProbeFacade.impl;
    if (bound === null) {
      return Promise.resolve('timeout');
    }
    return bound.tcpProbe(host, port, timeoutMs);
  }

  static httpHead(url: string, maxBody: number = HTTP_BODY_PREVIEW_MAX): Promise<HttpHeadResult> {
    const bound: LanProbeApi | null = LanProbeFacade.impl;
    if (bound === null) {
      const empty: HttpHeadResult = {
        status: 0,
        contentType: '',
        bodyPreview: ''
      };
      return Promise.resolve(empty);
    }
    return bound.httpHead(url, maxBody);
  }

  static tcpProbeForDevice(
    deviceKey: string, host: string, port: number, timeoutMs: number = TCP_PROBE_TIMEOUT_MS): Promise<TcpProbeResult> {
    return LanProbeFacade.tcpProbe(host, port, timeoutMs).then((result: TcpProbeResult): TcpProbeResult => {
      appendLanProbeLog(deviceKey, LogEventType.LAN_PROBE_TCP, `${host}:${port} ${result}`);
      return result;
    });
  }

  static httpHeadForDevice(
    deviceKey: string, url: string, maxBody: number = HTTP_BODY_PREVIEW_MAX): Promise<HttpHeadResult> {
    return LanProbeFacade.httpHead(url, maxBody).then((result: HttpHeadResult): HttpHeadResult => {
      appendLanProbeLog(
        deviceKey,
        LogEventType.LAN_PROBE_HTTP,
        `${result.status} ${result.contentType} ${result.bodyPreview}`
      );
      return result;
    }).catch((err: Object): Promise<HttpHeadResult> => {
      appendLanProbeLog(deviceKey, LogEventType.LAN_PROBE_HTTP, 'failed');
      return Promise.reject(err);
    });
  }
}

function appendLanProbeLog(deviceKey: string, type: string, message: string): void {
  const domain: LogEventDomain = 'lan';
  const event: LogEvent = {
    ts: Date.now(),
    deviceKey: deviceKey,
    domain: domain,
    type: type,
    message: message
  };
  LogEventBus.append(event);
}
