export type TcpProbeResult = 'open' | 'closed' | 'timeout';

export const TCP_PROBE_TIMEOUT_MS: number = 3000;
export const HTTP_BODY_PREVIEW_MAX: number = 512;
export const HTTP_PROBE_METHOD: string = 'GET';

export interface HostPort {
  host: string;
  port: number;
}

export interface HttpHeadResult {
  status: number;
  contentType: string;
  bodyPreview: string;
}

export function parseHostPort(detailLine: string): HostPort | null {
  const idx: number = detailLine.lastIndexOf(':');
  if (idx <= 0 || idx >= detailLine.length - 1) {
    return null;
  }
  const host: string = detailLine.substring(0, idx);
  const portStr: string = detailLine.substring(idx + 1);
  const port: number = Number.parseInt(portStr, 10);
  if (host.length === 0 || !Number.isFinite(port) || port <= 0 || port > 65535) {
    return null;
  }
  const parsed: HostPort = {
    host: host,
    port: port
  };
  return parsed;
}

export function httpUrlForHostPort(host: string, port: number): string {
  return `http://${host}:${port}/`;
}

export function previewBody(body: string, maxBody: number): string {
  if (maxBody <= 0) {
    return '';
  }
  if (body.length <= maxBody) {
    return body;
  }
  return body.substring(0, maxBody);
}

export function contentTypeFromHeader(header: Object): string {
  const raw: string = JSON.stringify(header);
  const lower: string = raw.toLowerCase();
  const marker: string = '"content-type":"';
  const idx: number = lower.indexOf(marker);
  if (idx < 0) {
    return '';
  }
  const start: number = idx + marker.length;
  const end: number = raw.indexOf('"', start);
  if (end <= start) {
    return '';
  }
  return raw.substring(start, end);
}

export function formatLanExtraLine(serviceTypes: string[], txtLine: string): string {
  const services: string = serviceTypes.join(' · ');
  if (txtLine.length === 0) {
    return services;
  }
  if (services.length === 0) {
    return txtLine;
  }
  return `${services} · ${txtLine}`;
}
