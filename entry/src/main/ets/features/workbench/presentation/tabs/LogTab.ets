import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { AppleTheme } from '../../../../shared/theme/AppleTheme';
import { InventoryDeviceKind } from '../../../discovery/domain/HomeInventoryDevice';
import { LogEvent, LogEventDomain } from '../../../session-log/domain/LogEvent';
import { LogEventBus } from '../../../session-log/domain/LogEventBus';
import { buildLogSharePayload, LogSharePayload } from '../../../session-log/domain/LogSharePayload';

@Component
export struct LogTab {
  @Prop deviceKey: string = '';
  @Prop kind: InventoryDeviceKind = InventoryDeviceKind.Ble;
  @State events: LogEvent[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  private logDomain(): LogEventDomain {
    if (this.kind === InventoryDeviceKind.Lan) {
      const lan: LogEventDomain = 'lan';
      return lan;
    }
    const ble: LogEventDomain = 'ble';
    return ble;
  }

  private reload(): void {
    this.events = LogEventBus.query(this.deviceKey, this.logDomain());
  }

  private exportLogs(): void {
    const text: string = LogEventBus.exportText(this.deviceKey);
    const payload: LogSharePayload = buildLogSharePayload(text);
    const record: systemShare.SharedRecord = {
      utd: payload.utd,
      content: payload.content,
      title: payload.title
    };
    const data: systemShare.SharedData = new systemShare.SharedData(record);
    const controller: systemShare.ShareController = new systemShare.ShareController(data);
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const options: systemShare.ShareControllerOptions = {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT
    };
    try {
      controller.show(context, options).catch((): void => {
        this.getUIContext().getPromptAction().showToast({
          message: $r('app.string.toast_export_failed')
        });
      });
    } catch (_err) {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.toast_export_failed')
      });
    }
  }

  build() {
    Column({ space: 12 }) {
      Button($r('app.string.workbench_btn_export'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(AppleTheme.TOUCH_TARGET_VP)
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.PRIMARY)
        .backgroundColor(AppleTheme.CANVAS)
        .border({ width: 1, color: AppleTheme.PRIMARY })
        .borderRadius(AppleTheme.RADIUS_PILL)
        .accessibilityText($r('app.string.a11y_export_log'))
        .onClick(() => {
          this.exportLogs();
        })
      if (this.events.length === 0) {
        Text($r('app.string.workbench_log_empty'))
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      } else {
        List({ space: 8 }) {
          ForEach(this.events, (item: LogEvent, index: number) => {
            ListItem() {
              Column({ space: 2 }) {
                Text(`${item.type}  ${item.ts}`)
                  .fontSize(AppleTheme.FONT_CAPTION)
                  .fontColor(AppleTheme.INK_MUTED)
                  .width('100%')
                Text(item.message)
                  .fontSize(AppleTheme.FONT_BODY)
                  .fontColor(AppleTheme.INK)
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
            }
          }, (item: LogEvent, index: number) => `${item.ts}-${item.type}-${index}`)
        }
        .scrollBar(BarState.Auto)
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
