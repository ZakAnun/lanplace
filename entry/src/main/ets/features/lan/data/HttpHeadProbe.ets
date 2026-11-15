import {
  HTTP_BODY_PREVIEW_MAX,
  HTTP_PROBE_METHOD,
  HttpHeadResult,
  contentTypeFromHeader,
  previewBody
} from '../domain/ProbeTypes';

export interface HttpTransportResponse {
  status: number;
  header: Object;
  body: string;
}

export interface HttpGetTransport {
  request(url: string, method: string): Promise<HttpTransportResponse>;
}

export function httpHead(
  url: string, maxBody: number = HTTP_BODY_PREVIEW_MAX, transport?: HttpGetTransport): Promise<HttpHeadResult> {
  if (transport === undefined) {
    const empty: HttpHeadResult = {
      status: 0,
      contentType: '',
      bodyPreview: ''
    };
    return Promise.resolve(empty);
  }
  return transport.request(url, HTTP_PROBE_METHOD).then((response: HttpTransportResponse): HttpHeadResult => {
    const mapped: HttpHeadResult = {
      status: response.status,
      contentType: contentTypeFromHeader(response.header),
      bodyPreview: previewBody(response.body, maxBody)
    };
    return mapped;
  });
}
