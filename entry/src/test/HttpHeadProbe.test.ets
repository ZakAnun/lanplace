import { describe, it, expect } from '@ohos/hypium';
import {
  HTTP_BODY_PREVIEW_MAX,
  HTTP_PROBE_METHOD,
  HttpHeadResult,
  contentTypeFromHeader,
  previewBody
} from '../main/ets/features/lan/domain/ProbeTypes';
import {
  HttpGetTransport,
  HttpTransportResponse,
  httpHead
} from '../main/ets/features/lan/data/HttpHeadProbe';

class RecordingHttpTransport implements HttpGetTransport {
  lastUrl: string = '';
  lastMethod: string = '';
  readonly response: HttpTransportResponse;

  constructor(response: HttpTransportResponse) {
    this.response = response;
  }

  request(url: string, method: string): Promise<HttpTransportResponse> {
    this.lastUrl = url;
    this.lastMethod = method;
    return Promise.resolve(this.response);
  }
}

function longBody(length: number): string {
  let out: string = '';
  for (let i = 0; i < length; i++) {
    out += 'a';
  }
  return out;
}

function headerFromJson(text: string): Object {
  return JSON.parse(text) as Object;
}

function httpResponse(status: number, headerJson: string, body: string): HttpTransportResponse {
  const response: HttpTransportResponse = {
    status: status,
    header: headerFromJson(headerJson),
    body: body
  };
  return response;
}

export default function httpHeadProbeTest() {
  describe('HttpHeadProbe', () => {
    it('previewBodyCapsAtMax', 0, () => {
      expect(HTTP_BODY_PREVIEW_MAX).assertEqual(512);
      expect(previewBody('short', 512)).assertEqual('short');
      const body: string = longBody(600);
      const preview: string = previewBody(body, HTTP_BODY_PREVIEW_MAX);
      expect(preview.length).assertEqual(512);
      expect(preview).assertEqual(body.substring(0, 512));
    });

    it('contentTypeFromHeaderIsCaseInsensitive', 0, () => {
      expect(contentTypeFromHeader(headerFromJson('{"content-type":"text/plain"}'))).assertEqual('text/plain');
      expect(contentTypeFromHeader(headerFromJson('{"Content-Type":"application/json"}'))).assertEqual(
        'application/json');
      expect(contentTypeFromHeader(headerFromJson('{}'))).assertEqual('');
    });

    it('httpHeadUsesGetOnly', 0, async (): Promise<void> => {
      const transport: RecordingHttpTransport = new RecordingHttpTransport(
        httpResponse(200, '{"content-type":"text/html"}', 'ok'));
      await httpHead('http://192.168.1.20:8009/', 512, transport);
      expect(transport.lastMethod).assertEqual(HTTP_PROBE_METHOD);
      expect(HTTP_PROBE_METHOD).assertEqual('GET');
      expect(transport.lastUrl).assertEqual('http://192.168.1.20:8009/');
    });

    it('httpHeadMapsStatusTypeAndPreview', 0, async (): Promise<void> => {
      const body: string = longBody(600);
      const transport: RecordingHttpTransport = new RecordingHttpTransport(
        httpResponse(200, '{"Content-Type":"text/plain"}', body));
      const result: HttpHeadResult = await httpHead('http://192.168.1.30:631/', 512, transport);
      expect(result.status).assertEqual(200);
      expect(result.contentType).assertEqual('text/plain');
      expect(result.bodyPreview.length).assertEqual(512);
      expect(result.bodyPreview).assertEqual(body.substring(0, 512));
    });
  });
}
