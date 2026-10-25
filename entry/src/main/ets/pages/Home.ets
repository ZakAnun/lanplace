import { common, Want } from '@kit.AbilityKit';
import { PromptAction, router } from '@kit.ArkUI';
import { AppleTheme } from '../common/AppleTheme';
import { PRIVACY_POLICY_URL } from '../common/Constants';
import { PrivacyConsentHelper } from '../common/PrivacyConsentHelper';
import { BleDiscoveryRadar } from '../components/BleDiscoveryRadar';
import { PrivacyConsentDialog } from '../components/PrivacyConsentDialog';
import {
  computeRadarCanvasSize,
  isLandscapeLayout,
  LANDSCAPE_RIGHT_RAIL_WIDTH,
  radarZoneWidth
} from '../common/RadarLayoutHelper';
import { WindowLayoutStore } from '../common/WindowLayoutStore';

@Entry
@Component
struct Home {
  @State radarActive: boolean = true;
  @State idleRadarSelectionId: string = '';
  @State idleRadarCanvasSize: number = 280;
  @State pageAreaWidth: number = 0;
  @State pageAreaHeight: number = 0;
  @State pageLandscape: boolean = false;
  @StorageLink(WindowLayoutStore.WIDTH_KEY) @Watch('onWindowMetricsChanged') mainWindowWidth: number = 0;
  @StorageLink(WindowLayoutStore.HEIGHT_KEY) @Watch('onWindowMetricsChanged') mainWindowHeight: number = 0;
  private privacyDialogController: CustomDialogController | null = null;
  private actionInFlight: boolean = false;

  private abilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private prompt(): PromptAction {
    return this.getUIContext().getPromptAction();
  }

  aboutToAppear(): void {
    const context = this.abilityContext();
    this.privacyDialogController = new CustomDialogController({
      builder: PrivacyConsentDialog({
        onAgree: () => {
          this.privacyDialogController?.close();
          PrivacyConsentHelper.setPrivacyAccepted(context, true).then(() => {
            this.openHomeInventory();
          }).catch(() => {
            this.prompt().showToast({ message: $r('app.string.toast_privacy_save_failed') });
          });
        },
        onDecline: () => {
          this.privacyDialogController?.close();
          context.terminateSelf();
        },
        onOpenPolicy: () => {
          this.openPrivacyPolicy();
        }
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center
    });
    PrivacyConsentHelper.isPrivacyAccepted(context).then((accepted) => {
      if (!accepted) {
        this.privacyDialogController?.open();
      }
    }).catch(() => {
      // ignore prefs read errors on first launch
    });
    this.radarActive = true;
    this.syncPageOrientation(this.pageAreaWidth, this.pageAreaHeight);
    this.refreshIdleRadarSize();
  }

  onPageShow(): void {
    this.radarActive = true;
    this.syncPageOrientation(this.pageAreaWidth, this.pageAreaHeight);
    this.refreshIdleRadarSize();
  }

  private openPrivacyPolicy(): void {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: PRIVACY_POLICY_URL
    };
    this.abilityContext().startAbility(want).catch(() => {
      this.prompt().showToast({ message: $r('app.string.toast_open_policy_failed') });
    });
  }

  private async onPrimaryAction(): Promise<void> {
    if (this.actionInFlight) {
      return;
    }
    try {
      this.actionInFlight = true;
      const accepted = await PrivacyConsentHelper.isPrivacyAccepted(this.abilityContext());
      if (!accepted) {
        this.privacyDialogController?.open();
        return;
      }
      this.openHomeInventory();
    } catch (_err) {
      this.prompt().showToast({ message: $r('app.string.toast_action_failed') });
    } finally {
      this.actionInFlight = false;
    }
  }

  private refreshIdleRadarSize(): void {
    if (this.pageAreaWidth <= 0 || this.pageAreaHeight <= 0) {
      return;
    }
    const zoneW = radarZoneWidth(this.pageAreaWidth, this.pageLandscape);
    this.idleRadarCanvasSize = computeRadarCanvasSize(zoneW, this.pageAreaHeight, this.pageLandscape);
  }

  private syncPageAreaFromChange(width: number, height: number): void {
    if (width > 0 && height > 0) {
      this.pageAreaWidth = width;
      this.pageAreaHeight = height;
      this.syncPageOrientation(width, height);
      this.refreshIdleRadarSize();
    }
  }

  onWindowMetricsChanged(): void {
    if (this.mainWindowWidth > 0 && this.mainWindowHeight > 0) {
      this.applyPageLandscape(this.mainWindowWidth, this.mainWindowHeight);
    } else {
      this.applyPageLandscape(this.pageAreaWidth, this.pageAreaHeight);
    }
    this.refreshIdleRadarSize();
  }

  private applyPageLandscape(width: number, height: number): void {
    if (width > 0 && height > 0) {
      this.pageLandscape = isLandscapeLayout(width, height);
    }
  }

  private syncPageOrientation(areaWidth: number, areaHeight: number): void {
    let width = areaWidth;
    let height = areaHeight;
    if (width <= 0 || height <= 0) {
      width = this.mainWindowWidth;
      height = this.mainWindowHeight;
    }
    this.applyPageLandscape(width, height);
  }

  private openHomeInventory(): void {
    router.pushUrl({ url: 'pages/HomeInventory' }).catch(() => {
      this.prompt().showToast({ message: $r('app.string.toast_open_inventory_failed') });
    });
  }

  @Builder
  idleRadarBlock() {
    Stack({ alignContent: Alignment.Center }) {
      BleDiscoveryRadar({
        active: this.radarActive,
        devices: [],
        selectedDeviceId: $idleRadarSelectionId,
        canvasSize: this.idleRadarCanvasSize
      })
    }
    .width('100%')
    .height(this.idleRadarCanvasSize)
    .alignContent(Alignment.Center)
  }

  @Builder
  idlePortraitHeadline() {
    Column({ space: 8 }) {
      Text($r('app.string.EntryAbility_label'))
        .fontSize(AppleTheme.FONT_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
        .letterSpacing(-0.5)
        .textAlign(TextAlign.Center)
        .width('100%')
      Text($r('app.string.home_idle_caption'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.INK_MUTED)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  idlePrimaryButton() {
    Button($r('app.string.btn_home_inventory'))
      .fontSize(AppleTheme.FONT_BODY)
      .fontColor(AppleTheme.CANVAS)
      .backgroundColor(AppleTheme.PRIMARY)
      .borderRadius(AppleTheme.RADIUS_PILL)
      .padding({ left: 22, right: 22, top: 11, bottom: 11 })
      .accessibilityText($r('app.string.a11y_home_inventory'))
      .onClick(() => {
        this.onPrimaryAction();
      })
  }

  @Builder
  idleLandscapeIconRail() {
    Column({ space: 14 }) {
      Text('近')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK_MUTED)
      Blank()
        .layoutWeight(1)
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('⌕')
          .fontSize(22)
          .fontColor(AppleTheme.CANVAS)
          .fontWeight(FontWeight.Medium)
      }
      .width(48)
      .height(48)
      .backgroundColor(AppleTheme.PRIMARY)
      .accessibilityText($r('app.string.a11y_home_inventory'))
      .onClick(() => {
        this.onPrimaryAction();
      })
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('i')
          .fontSize(16)
          .fontColor(AppleTheme.PRIMARY)
          .fontWeight(FontWeight.Medium)
      }
      .width(48)
      .height(48)
      .backgroundColor(AppleTheme.CANVAS)
      .border({ width: 1, color: AppleTheme.PRIMARY })
      .accessibilityText($r('app.string.a11y_privacy'))
      .onClick(() => {
        this.openPrivacyPolicy();
      })
    }
    .width(LANDSCAPE_RIGHT_RAIL_WIDTH)
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  idlePrivacyLink() {
    Text($r('app.string.label_privacy'))
      .fontSize(AppleTheme.FONT_CAPTION)
      .fontColor(AppleTheme.PRIMARY)
      .accessibilityText($r('app.string.a11y_privacy'))
      .onClick(() => this.openPrivacyPolicy())
  }

  @Builder
  idlePortraitBody() {
    Column({ space: 20 }) {
      this.idleRadarBlock()
      this.idlePortraitHeadline()
      Row() {
        this.idlePrimaryButton()
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      Row() {
        this.idlePrivacyLink()
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  idleLandscapeBody() {
    Row({ space: 12 }) {
      Column() {
        this.idleRadarBlock()
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      this.idleLandscapeIconRail()
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  idleView() {
    Column() {
      if (this.pageLandscape) {
        Column() {
          this.idleLandscapeBody()
        }
        .width('100%')
        .height('100%')
      } else {
        this.idlePortraitBody()
      }
    }
    .layoutWeight(1)
    .width('100%')
    .height('100%')
    .justifyContent(this.pageLandscape ? FlexAlign.Start : FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(this.pageLandscape
      ? { left: 16, right: 16, top: 12, bottom: 12 }
      : { left: 24, right: 24, top: 24, bottom: 24 })
    .backgroundColor(AppleTheme.PARCHMENT)
    .onAreaChange((_old, area) => {
      this.syncPageAreaFromChange(area.width as number, area.height as number);
    })
  }

  build() {
    Column() {
      this.idleView()
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
