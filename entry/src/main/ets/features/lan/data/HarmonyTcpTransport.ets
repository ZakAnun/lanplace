import { socket } from '@kit.NetworkKit';
import { TCP_PROBE_TIMEOUT_MS } from '../domain/ProbeTypes';
import { TcpConnectTransport } from './TcpProbe';

export class HarmonyTcpTransport implements TcpConnectTransport {
  private current: socket.TCPSocket | null = null;

  connect(host: string, port: number, timeoutMs: number): Promise<void> {
    this.abort();
    const tcp: socket.TCPSocket = socket.constructTCPSocketInstance();
    this.current = tcp;
    const timeout: number = timeoutMs > 0 ? timeoutMs : TCP_PROBE_TIMEOUT_MS;
    const options: socket.TCPConnectOptions = {
      address: {
        address: host,
        port: port,
        family: 1
      },
      timeout: timeout
    };
    return tcp.connect(options).then((): void => {
      this.closeQuiet(tcp);
    }).catch((err: Object): Promise<void> => {
      this.closeQuiet(tcp);
      return Promise.reject(err);
    });
  }

  abort(): void {
    const tcp: socket.TCPSocket | null = this.current;
    this.current = null;
    if (tcp !== null) {
      this.closeQuiet(tcp);
    }
  }

  private closeQuiet(tcp: socket.TCPSocket): void {
    tcp.close().then((): void => {
    }).catch((): void => {
    });
  }
}
