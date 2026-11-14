const HEART_RATE_MEASUREMENT: string = '2a37';
const TEMPERATURE: string = '2a6e';

function assignedNumber(uuid: string): string {
  let text: string = uuid.trim().toLowerCase();
  if (text.startsWith('0x')) {
    text = text.substring(2);
  }
  const dash: number = text.indexOf('-');
  if (dash >= 0) {
    text = text.substring(0, dash);
  }
  let compact: string = '';
  for (let i = 0; i < text.length; i++) {
    const ch: string = text.substring(i, i + 1);
    if (ch !== ':' && ch !== ' ') {
      compact += ch;
    }
  }
  if (compact.length > 4) {
    return compact.substring(compact.length - 4);
  }
  return compact;
}

export function sigCharacteristicName(uuid: string): string {
  const key: string = assignedNumber(uuid);
  if (key === HEART_RATE_MEASUREMENT) {
    return 'Heart Rate Measurement';
  }
  if (key === TEMPERATURE) {
    return 'Temperature';
  }
  return '';
}
