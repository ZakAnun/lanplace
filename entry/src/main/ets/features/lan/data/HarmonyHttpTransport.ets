import { http } from '@kit.NetworkKit';
import { TCP_PROBE_TIMEOUT_MS } from '../domain/ProbeTypes';
import { HttpGetTransport, HttpTransportResponse } from './HttpHeadProbe';

export class HarmonyHttpTransport implements HttpGetTransport {
  request(url: string, _method: string): Promise<HttpTransportResponse> {
    const req: http.HttpRequest = http.createHttp();
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: TCP_PROBE_TIMEOUT_MS,
      readTimeout: TCP_PROBE_TIMEOUT_MS,
      usingCache: false
    };
    return req.request(url, options).then((response: http.HttpResponse): HttpTransportResponse => {
      req.destroy();
      const mapped: HttpTransportResponse = {
        status: response.responseCode as number,
        header: response.header,
        body: httpBodyText(response.result)
      };
      return mapped;
    }).catch((err: Object): Promise<HttpTransportResponse> => {
      req.destroy();
      return Promise.reject(err);
    });
  }
}

function httpBodyText(result: string | Object | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result as string;
  }
  try {
    return JSON.stringify(result);
  } catch (_err) {
    return '';
  }
}
