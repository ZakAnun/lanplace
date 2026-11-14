export type TcpProbeResult = 'open' | 'closed' | 'timeout';

export const TCP_PROBE_TIMEOUT_MS: number = 3000;
export const NATIVE_TCP_CONNECT_TIMEOUT_MS: number = 60000;
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

export function printableTxtBytes(bytes: Array<number>): string {
  const decoded: string = decodeUtf8Bytes(bytes);
  let out: string = '';
  for (let i = 0; i < decoded.length; i++) {
    const code: number = decoded.charCodeAt(i);
    if (code < 32 || code === 127) {
      continue;
    }
    out += decoded.charAt(i);
  }
  return out;
}

function decodeUtf8Bytes(bytes: Array<number>): string {
  let out: string = '';
  let i: number = 0;
  while (i < bytes.length) {
    const b0: number = bytes[i] & 0xff;
    if (b0 < 0x80) {
      out += String.fromCharCode(b0);
      i += 1;
      continue;
    }
    if (b0 >= 0xc0 && b0 < 0xe0 && i + 1 < bytes.length && isUtf8Continuation(bytes[i + 1])) {
      const code: number = ((b0 & 0x1f) << 6) | (bytes[i + 1] & 0x3f);
      out += String.fromCharCode(code);
      i += 2;
      continue;
    }
    if (b0 >= 0xe0 && b0 < 0xf0 && i + 2 < bytes.length &&
      isUtf8Continuation(bytes[i + 1]) && isUtf8Continuation(bytes[i + 2])) {
      const code: number = ((b0 & 0x0f) << 12) | ((bytes[i + 1] & 0x3f) << 6) | (bytes[i + 2] & 0x3f);
      out += String.fromCharCode(code);
      i += 3;
      continue;
    }
    if (b0 >= 0xf0 && b0 < 0xf8 && i + 3 < bytes.length &&
      isUtf8Continuation(bytes[i + 1]) && isUtf8Continuation(bytes[i + 2]) &&
      isUtf8Continuation(bytes[i + 3])) {
      const code: number =
        ((b0 & 0x07) << 18) | ((bytes[i + 1] & 0x3f) << 12) | ((bytes[i + 2] & 0x3f) << 6) | (bytes[i + 3] & 0x3f);
      const extra: number = code - 0x10000;
      out += String.fromCharCode(0xd800 + (extra >> 10), 0xdc00 + (extra & 0x3ff));
      i += 4;
      continue;
    }
    i += 1;
  }
  return out;
}

function isUtf8Continuation(raw: number): boolean {
  return (raw & 0xc0) === 0x80;
}
