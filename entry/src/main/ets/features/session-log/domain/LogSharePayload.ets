export const LOG_SHARE_PLAIN_TEXT: string = 'general.plain-text';
export const LOG_SHARE_TITLE: string = 'BlueScopes';

export interface LogSharePayload {
  utd: string;
  content: string;
  title: string;
}

export function buildLogSharePayload(text: string): LogSharePayload {
  const payload: LogSharePayload = {
    utd: LOG_SHARE_PLAIN_TEXT,
    content: text,
    title: LOG_SHARE_TITLE
  };
  return payload;
}
