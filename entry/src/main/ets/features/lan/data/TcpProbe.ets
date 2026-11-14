import { NATIVE_TCP_CONNECT_TIMEOUT_MS, TCP_PROBE_TIMEOUT_MS, TcpProbeResult } from '../domain/ProbeTypes';

export interface TcpConnectTransport {
  connect(host: string, port: number, timeoutMs: number): Promise<void>;
  abort(): void;
}

export interface ProbeClock {
  schedule(delayMs: number, onFire: () => void): number;
  cancel(timerId: number): void;
}

export class SystemProbeClock implements ProbeClock {
  schedule(delayMs: number, onFire: () => void): number {
    const timerId: number = setTimeout(onFire, delayMs) as number;
    return timerId;
  }

  cancel(timerId: number): void {
    clearTimeout(timerId);
  }
}

export function tcpProbe(
  host: string, port: number, timeoutMs: number = TCP_PROBE_TIMEOUT_MS, transport?: TcpConnectTransport,
  clock?: ProbeClock): Promise<TcpProbeResult> {
  const usedClock: ProbeClock = clock !== undefined ? clock : new SystemProbeClock();
  const usedTransport: TcpConnectTransport | undefined = transport;
  if (usedTransport === undefined) {
    return Promise.resolve('closed');
  }
  return new Promise<TcpProbeResult>(
    (resolve: (result: TcpProbeResult) => void): void => {
      let settled: boolean = false;
      const timerId: number = usedClock.schedule(timeoutMs, (): void => {
        if (settled) {
          return;
        }
        settled = true;
        usedTransport.abort();
        resolve('timeout');
      });
      usedTransport.connect(host, port, NATIVE_TCP_CONNECT_TIMEOUT_MS).then((): void => {
        if (settled) {
          return;
        }
        settled = true;
        usedClock.cancel(timerId);
        resolve('open');
      }).catch((err: Object): void => {
        if (settled) {
          return;
        }
        settled = true;
        usedClock.cancel(timerId);
        if (isTimeoutShapedError(err)) {
          resolve('timeout');
          return;
        }
        resolve('closed');
      });
    }
  );
}

function isTimeoutShapedError(err: Object): boolean {
  const asError: Error = err as Error;
  const message: string = asError.message !== undefined ? `${asError.message}` : `${err}`;
  const lower: string = message.toLowerCase();
  return lower.indexOf('timeout') >= 0 || lower.indexOf('timed out') >= 0;
}
