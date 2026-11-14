import { AppleTheme } from '../../../../shared/theme/AppleTheme';
import { LanProbeFacade } from '../../../lan/domain/LanProbeFacade';
import {
  HostPort,
  HttpHeadResult,
  httpUrlForHostPort,
  parseHostPort,
  TcpProbeResult
} from '../../../lan/domain/ProbeTypes';

@Component
export struct LanTab {
  @Prop deviceKey: string = '';
  @Prop detailLine: string = '';
  @Prop extraLine: string = '';
  @State tcpResult: string = '';
  @State httpStatus: string = '';
  @State httpContentType: string = '';
  @State httpPreview: string = '';
  @State probing: boolean = false;

  private target(): HostPort | null {
    return parseHostPort(this.detailLine);
  }

  private onTcpProbe(): void {
    const parsed: HostPort | null = this.target();
    if (parsed === null || this.probing) {
      return;
    }
    this.probing = true;
    LanProbeFacade.tcpProbeForDevice(this.deviceKey, parsed.host, parsed.port).then((result: TcpProbeResult): void => {
      this.tcpResult = result;
      this.probing = false;
    }).catch((): void => {
      this.probing = false;
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.toast_action_failed')
      });
    });
  }

  private onHttpProbe(): void {
    const parsed: HostPort | null = this.target();
    if (parsed === null || this.probing) {
      return;
    }
    this.probing = true;
    const url: string = httpUrlForHostPort(parsed.host, parsed.port);
    LanProbeFacade.httpHeadForDevice(this.deviceKey, url).then((result: HttpHeadResult): void => {
      this.httpStatus = `${result.status}`;
      this.httpContentType = result.contentType;
      this.httpPreview = result.bodyPreview;
      this.probing = false;
    }).catch((): void => {
      this.probing = false;
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.toast_action_failed')
      });
    });
  }

  @Builder
  fieldRow(label: Resource, value: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .width('100%')
      Text(value)
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.INK)
        .fontFamily('HarmonyOS Sans')
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
      if (this.detailLine.length > 0) {
        this.fieldRow($r('app.string.workbench_lan_host'), this.detailLine)
      }
      if (this.extraLine.length > 0) {
        this.fieldRow($r('app.string.workbench_lan_services'), this.extraLine)
      }
      if (this.target() === null) {
        Text($r('app.string.workbench_lan_empty_target'))
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      } else {
        Button($r('app.string.workbench_lan_btn_tcp'))
          .type(ButtonType.Normal)
          .width('100%')
          .height(AppleTheme.TOUCH_TARGET_VP)
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.CANVAS)
          .backgroundColor(AppleTheme.LAN_TEXT)
          .borderRadius(AppleTheme.RADIUS_PILL)
          .enabled(!this.probing)
          .accessibilityText($r('app.string.a11y_lan_tcp_probe'))
          .onClick(() => {
            this.onTcpProbe();
          })
        Button($r('app.string.workbench_lan_btn_http'))
          .type(ButtonType.Normal)
          .width('100%')
          .height(AppleTheme.TOUCH_TARGET_VP)
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.LAN_TEXT)
          .backgroundColor(AppleTheme.CANVAS)
          .border({ width: 1, color: AppleTheme.LAN_TEXT })
          .borderRadius(AppleTheme.RADIUS_PILL)
          .enabled(!this.probing)
          .accessibilityText($r('app.string.a11y_lan_http_probe'))
          .onClick(() => {
            this.onHttpProbe();
          })
      }
      if (this.probing) {
        Text($r('app.string.workbench_lan_probing'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      }
      if (this.tcpResult.length > 0) {
        this.fieldRow($r('app.string.workbench_lan_tcp_result'), this.tcpResult)
      }
      if (this.httpStatus.length > 0) {
        this.fieldRow($r('app.string.workbench_lan_http_result'),
          `${this.httpStatus} ${this.httpContentType}`.trim())
        if (this.httpPreview.length > 0) {
          Text(this.httpPreview)
            .fontSize(AppleTheme.FONT_CAPTION)
            .fontColor(AppleTheme.INK_MUTED)
            .fontFamily('HarmonyOS Sans')
            .width('100%')
        }
      }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .scrollBar(BarState.Auto)
    .width('100%')
    .height('100%')
  }
}
