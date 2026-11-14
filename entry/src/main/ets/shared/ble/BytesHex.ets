export class InvalidHexError extends Error {
  readonly kind: string = 'InvalidHexError';

  constructor() {
    super('invalid hex');
  }
}

function isSeparator(ch: string): boolean {
  return ch === ':' || ch === ' ' || ch === '-' || ch === '\n' || ch === '\r' || ch === '\t';
}

function nibble(ch: string): number {
  const code: number = ch.charCodeAt(0);
  if (code >= 48 && code <= 57) {
    return code - 48;
  }
  if (code >= 65 && code <= 70) {
    return code - 55;
  }
  if (code >= 97 && code <= 102) {
    return code - 87;
  }
  return -1;
}

export function bytesToHex(bytes: Uint8Array): string {
  const parts: string[] = [];
  for (let i = 0; i < bytes.length; i++) {
    const pair: string = bytes[i].toString(16).toUpperCase().padStart(2, '0');
    parts.push(pair);
  }
  return parts.join(':');
}

export function hexToBytes(hex: string): Uint8Array {
  let compact: string = '';
  for (let i = 0; i < hex.length; i++) {
    const ch: string = hex.substring(i, i + 1);
    if (isSeparator(ch)) {
      continue;
    }
    compact += ch;
  }
  if (compact.length === 0) {
    return new Uint8Array(0);
  }
  if (compact.length % 2 !== 0) {
    throw new InvalidHexError();
  }
  const out: Uint8Array = new Uint8Array(compact.length / 2);
  for (let i = 0; i < out.length; i++) {
    const hi: number = nibble(compact.substring(i * 2, i * 2 + 1));
    const lo: number = nibble(compact.substring(i * 2 + 1, i * 2 + 2));
    if (hi < 0 || lo < 0) {
      throw new InvalidHexError();
    }
    out[i] = hi * 16 + lo;
  }
  return out;
}
