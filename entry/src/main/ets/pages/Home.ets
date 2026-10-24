import { common, Want } from '@kit.AbilityKit';
import { PromptAction } from '@kit.ArkUI';
import { AppleTheme } from '../common/AppleTheme';
import { PRIVACY_POLICY_URL } from '../common/Constants';
import { PermissionHelper } from '../common/PermissionHelper';
import { PrivacyConsentHelper } from '../common/PrivacyConsentHelper';
import { BluetoothHelper } from '../common/BluetoothHelper';
import { BleScanCoordinator } from '../service/BleScanCoordinator';
import { BLE_SCAN_STOP_QUIET, BLE_SCAN_STOP_WITH_COMPLETE } from '../service/BleScanService';
import { ScannedDevice } from '../model/ScannedDevice';
import { NearbyDevicePanel } from '../components/NearbyDevicePanel';
import { PrivacyConsentDialog } from '../components/PrivacyConsentDialog';
import { BleDiscoveryRadar } from '../components/BleDiscoveryRadar';
import {
  computeRadarCanvasSize,
  isLandscapeLayout,
  LANDSCAPE_RIGHT_RAIL_WIDTH,
  radarZoneWidth
} from '../common/RadarLayoutHelper';
import { WindowLayoutStore } from '../common/WindowLayoutStore';

enum UiPhase {
  Idle,
  Scanning,
  Results
}

@Entry
@Component
struct Home {
  @State phase: UiPhase = UiPhase.Idle;
  @State devices: ScannedDevice[] = [];
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

  private showToast(message: string): void {
    this.prompt().showToast({ message });
  }

  aboutToAppear(): void {
    const context = this.abilityContext();
    this.privacyDialogController = new CustomDialogController({
      builder: PrivacyConsentDialog({
        onAgree: () => {
          this.privacyDialogController?.close();
          PrivacyConsentHelper.setPrivacyAccepted(context, true).then(() => {
            this.beginScanFlow().catch(() => {
              this.showToast('操作失败，请重试');
            });
          }).catch(() => {
            this.showToast('无法保存隐私同意状态');
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

  aboutToDisappear(): void {
    BleScanCoordinator.stop(BLE_SCAN_STOP_QUIET);
  }

  onPageHide(): void {
    if (BleScanCoordinator.isScanning()) {
      BleScanCoordinator.stop(BLE_SCAN_STOP_WITH_COMPLETE);
      this.phase = UiPhase.Results;
    }
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
      this.showToast('无法打开隐私政策链接');
    });
  }

  private scanErrorMessage(err: Error): string {
    const raw = `${err.message ?? err}`;
    if (raw.includes('2900003') || raw.includes('2900001')) {
      return '请先开启系统蓝牙后再扫描';
    }
    if (raw.includes('201') || raw.includes('permission')) {
      return '未授予蓝牙权限';
    }
    return '无法开始扫描，请检查蓝牙与权限';
  }

  private async onPrimaryAction(): Promise<void> {
    if (this.actionInFlight || BleScanCoordinator.isScanning()) {
      this.showToast('正在扫描中');
      return;
    }
    try {
      this.actionInFlight = true;
      const accepted = await PrivacyConsentHelper.isPrivacyAccepted(this.abilityContext());
      if (!accepted) {
        this.privacyDialogController?.open();
        return;
      }
      await this.beginScanFlow();
    } catch (_err) {
      this.showToast('操作失败，请重试');
    } finally {
      this.actionInFlight = false;
    }
  }

  private async beginScanFlow(): Promise<void> {
    if (BleScanCoordinator.isScanning()) {
      this.showToast('正在扫描中');
      return;
    }
    const useMock = BleScanCoordinator.useMockScan();
    if (!useMock && !BluetoothHelper.isEnabled()) {
      this.showToast('请先开启系统蓝牙');
      return;
    }
    const context = this.abilityContext();
    const hasBt = useMock || await PermissionHelper.hasBluetoothPermission(context);
    if (!hasBt) {
      const ok = await this.prompt().showDialog({
        title: '蓝牙权限',
        message: '需要蓝牙权限以扫描周围设备，数据仅在本机展示。',
        buttons: [
          { text: '取消', color: AppleTheme.INK_MUTED },
          { text: '继续', color: AppleTheme.PRIMARY }
        ]
      });
      if (ok.index !== 1) {
        return;
      }
      let granted = await PermissionHelper.requestBluetoothPermission(context);
      if (!granted) {
        const goSetting = await this.prompt().showDialog({
          title: '需要蓝牙权限',
          message: '扫描需要蓝牙权限。您可稍后再试，或前往系统设置开启。',
          buttons: [
            { text: '取消', color: AppleTheme.INK_MUTED },
            { text: '去设置', color: AppleTheme.PRIMARY }
          ]
        });
        if (goSetting.index !== 1) {
          return;
        }
        granted = await PermissionHelper.requestBluetoothPermissionFromSetting(context);
        if (!granted) {
          this.showToast('仍未授予蓝牙权限');
          return;
        }
      }
    }
    this.phase = UiPhase.Scanning;
    this.devices = [];
    try {
      if (useMock) {
        this.prompt().showToast({ message: $r('app.string.toast_mock_demo') });
      }
      const started = BleScanCoordinator.start(
        (list: ScannedDevice[]) => {
          this.devices = list.slice();
        },
        () => {
          this.phase = UiPhase.Results;
        }
      );
      if (!started) {
        this.showToast('正在扫描中');
        this.phase = UiPhase.Idle;
      }
    } catch (e) {
      this.showToast(this.scanErrorMessage(e as Error));
      this.phase = UiPhase.Idle;
    }
  }

  private stopScan(): void {
    BleScanCoordinator.stop(BLE_SCAN_STOP_WITH_COMPLETE);
    this.phase = UiPhase.Results;
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
    Button($r('app.string.btn_start_scan'))
      .fontSize(AppleTheme.FONT_BODY)
      .fontColor(AppleTheme.CANVAS)
      .backgroundColor(AppleTheme.PRIMARY)
      .borderRadius(AppleTheme.RADIUS_PILL)
      .padding({ left: 22, right: 22, top: 11, bottom: 11 })
      .accessibilityText($r('app.string.a11y_start_scan'))
      .onClick(() => {
        this.onPrimaryAction();
      })
  }

  @Builder
  idleLandscapeIconRail() {
    Column({ space: 14 }) {
      Text('BT')
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
      .accessibilityText($r('app.string.a11y_start_scan'))
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

  @Builder
  browseHeader() {
    Text($r('app.string.home_title'))
      .fontSize(24)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppleTheme.INK)
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ bottom: 4 })
  }

  @Builder
  scanStopButton() {
    Button($r('app.string.btn_stop_scan'))
      .fontSize(AppleTheme.FONT_BODY)
      .fontColor(AppleTheme.PRIMARY)
      .backgroundColor(AppleTheme.CANVAS)
      .border({ width: 1, color: AppleTheme.PRIMARY })
      .borderRadius(AppleTheme.RADIUS_PILL)
      .accessibilityText($r('app.string.a11y_stop_scan'))
      .onClick(() => this.stopScan())
  }

  @Builder
  scanFooterIcon() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Text('■')
        .fontSize(16)
        .fontColor(AppleTheme.PRIMARY)
        .fontWeight(FontWeight.Medium)
    }
    .width(48)
    .height(48)
    .backgroundColor(AppleTheme.CANVAS)
    .border({ width: 1, color: AppleTheme.PRIMARY })
    .accessibilityText($r('app.string.a11y_stop_scan'))
    .onClick(() => {
      this.stopScan();
    })
  }

  @Builder
  rescanFooterIcon() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Text('↻')
        .fontSize(20)
        .fontColor(AppleTheme.CANVAS)
        .fontWeight(FontWeight.Medium)
    }
    .width(48)
    .height(48)
    .backgroundColor(AppleTheme.PRIMARY)
    .accessibilityText($r('app.string.a11y_rescan'))
    .onClick(() => {
      this.onPrimaryAction();
    })
  }

  @Builder
  rescanButton() {
    Button($r('app.string.btn_start_scan'))
      .fontSize(AppleTheme.FONT_BODY)
      .fontColor(AppleTheme.CANVAS)
      .backgroundColor(AppleTheme.PRIMARY)
      .borderRadius(AppleTheme.RADIUS_PILL)
      .accessibilityText($r('app.string.a11y_rescan'))
      .onClick(() => {
        this.onPrimaryAction();
      })
  }

  @Builder
  deviceBrowseShell(scanning: boolean) {
    Column({ space: 12 }) {
      NearbyDevicePanel({
        devices: this.devices,
        active: this.radarActive,
        scanning: scanning,
        isLandscapeLayout: this.pageLandscape,
        topBanner: this.browseHeader,
        footerIconAction: scanning ? this.scanFooterIcon : this.rescanFooterIcon
      })
        .layoutWeight(1)
        .width('100%')

      if (!this.pageLandscape) {
        if (scanning) {
          this.scanStopButton()
        } else {
          this.rescanButton()
        }
      }
    }
    .padding(this.pageLandscape
      ? { left: 16, right: 16, top: 12, bottom: 12 }
      : { left: 24, right: 24, top: 16, bottom: 24 })
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppleTheme.CANVAS)
    .onAreaChange((_old, area) => {
      this.syncPageAreaFromChange(area.width as number, area.height as number);
    })
  }

  build() {
    Column() {
      if (this.phase === UiPhase.Idle) {
        this.idleView()
      } else {
        this.deviceBrowseShell(this.phase === UiPhase.Scanning)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
