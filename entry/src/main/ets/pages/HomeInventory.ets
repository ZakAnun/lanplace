import { common } from '@kit.AbilityKit';
import { PromptAction, router } from '@kit.ArkUI';
import { AppleTheme } from '../common/AppleTheme';
import { BluetoothHelper } from '../common/BluetoothHelper';
import { PermissionHelper } from '../common/PermissionHelper';
import { PrivacyConsentHelper } from '../common/PrivacyConsentHelper';
import { WifiNetworkHelper } from '../common/WifiNetworkHelper';
import { isLandscapeLayout } from '../common/RadarLayoutHelper';
import { WindowLayoutStore } from '../common/WindowLayoutStore';
import { HomeInventoryPanel } from '../components/HomeInventoryPanel';
import { HomeInventoryDevice } from '../model/HomeInventoryDevice';
import { BleScanCoordinator } from '../service/BleScanCoordinator';
import { HomeInventoryCoordinator } from '../service/HomeInventoryCoordinator';

enum InventoryUiPhase {
  Scanning,
  Results
}

@Entry
@Component
struct HomeInventory {
  @State phase: InventoryUiPhase = InventoryUiPhase.Results;
  @State devices: HomeInventoryDevice[] = [];
  @State radarActive: boolean = true;
  @State wifiSsid: string = '';
  @State pageAreaWidth: number = 0;
  @State pageAreaHeight: number = 0;
  @State pageLandscape: boolean = false;
  @StorageLink(WindowLayoutStore.WIDTH_KEY) @Watch('onWindowMetricsChanged') mainWindowWidth: number = 0;
  @StorageLink(WindowLayoutStore.HEIGHT_KEY) @Watch('onWindowMetricsChanged') mainWindowHeight: number = 0;
  private actionInFlight: boolean = false;
  private pageAlive: boolean = true;

  private abilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private prompt(): PromptAction {
    return this.getUIContext().getPromptAction();
  }

  private mainWindowHeightVp(): number {
    if (this.mainWindowHeight <= 0) {
      return this.pageAreaHeight;
    }
    return this.getUIContext().px2vp(this.mainWindowHeight);
  }

  aboutToAppear(): void {
    this.pageAlive = true;
    this.radarActive = true;
    this.syncPageOrientation(this.pageAreaWidth, this.pageAreaHeight);
    this.startInventoryScan().catch(() => {
      this.phase = InventoryUiPhase.Results;
      this.prompt().showToast({ message: $r('app.string.toast_action_failed') });
    });
  }

  aboutToDisappear(): void {
    this.pageAlive = false;
    HomeInventoryCoordinator.stop(false);
  }

  onPageHide(): void {
    this.radarActive = false;
    if (HomeInventoryCoordinator.isScanning()) {
      HomeInventoryCoordinator.stop(true);
      this.phase = InventoryUiPhase.Results;
    }
  }

  onPageShow(): void {
    this.radarActive = true;
    this.refreshWifiSsid();
  }

  private async refreshWifiSsid(): Promise<void> {
    this.wifiSsid = await WifiNetworkHelper.linkedSsid();
  }

  private async ensureBluetoothPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (await PermissionHelper.hasBluetoothPermission(context)) {
      return true;
    }
    const preface = await this.prompt().showDialog({
      title: $r('app.string.dialog_bluetooth_title'),
      message: $r('app.string.dialog_bluetooth_message'),
      buttons: [
        { text: $r('app.string.dialog_btn_cancel'), color: AppleTheme.INK_MUTED },
        { text: $r('app.string.dialog_btn_continue'), color: AppleTheme.PRIMARY }
      ]
    });
    if (preface.index !== 1) {
      return false;
    }
    let granted = await PermissionHelper.requestBluetoothPermission(context);
    if (granted) {
      return true;
    }
    const goSetting = await this.prompt().showDialog({
      title: $r('app.string.dialog_bluetooth_denied_title'),
      message: $r('app.string.dialog_bluetooth_denied_message'),
      buttons: [
        { text: $r('app.string.dialog_btn_cancel'), color: AppleTheme.INK_MUTED },
        { text: $r('app.string.dialog_btn_go_settings'), color: AppleTheme.PRIMARY }
      ]
    });
    if (goSetting.index !== 1) {
      return false;
    }
    granted = await PermissionHelper.requestBluetoothPermissionFromSetting(context);
    if (!granted) {
      this.prompt().showToast({ message: $r('app.string.toast_bluetooth_permission_denied') });
    }
    return granted;
  }

  private async startInventoryScan(): Promise<void> {
    if (this.actionInFlight || HomeInventoryCoordinator.isScanning()) {
      return;
    }
    this.actionInFlight = true;
    try {
      const context = this.abilityContext();
      const accepted = await PrivacyConsentHelper.isPrivacyAccepted(context);
      if (!this.pageAlive) {
        return;
      }
      if (!accepted) {
        this.prompt().showToast({ message: $r('app.string.toast_privacy_required') });
        router.back();
        return;
      }

      const useMockBle = BleScanCoordinator.useMockScan();
      let enableBleScan = useMockBle;
      let enableLanScan = useMockBle;

      if (!useMockBle) {
        if (!BluetoothHelper.isEnabled()) {
          this.prompt().showToast({ message: $r('app.string.toast_bluetooth_off') });
        } else {
          const btGranted = await this.ensureBluetoothPermission(context);
          if (!this.pageAlive) {
            return;
          }
          enableBleScan = btGranted;
        }

        await this.refreshWifiSsid();
        if (!this.pageAlive) {
          return;
        }
        enableLanScan = WifiNetworkHelper.isWifiLinked();
        if (!enableLanScan) {
          this.prompt().showToast({ message: $r('app.string.toast_wifi_only_ble') });
        }
      } else {
        await this.refreshWifiSsid();
        if (!this.pageAlive) {
          return;
        }
      }

      if (!enableBleScan && !enableLanScan) {
        this.phase = InventoryUiPhase.Results;
        return;
      }

      if (!this.pageAlive) {
        return;
      }

      this.devices = [];
      this.phase = InventoryUiPhase.Scanning;

      if (useMockBle) {
        this.prompt().showToast({ message: $r('app.string.toast_mock_demo') });
      }

      const started = HomeInventoryCoordinator.start(
        context,
        (list: HomeInventoryDevice[]) => {
          if (!this.pageAlive) {
            return;
          }
          this.devices = list.slice();
        },
        () => {
          if (!this.pageAlive) {
            return;
          }
          this.phase = InventoryUiPhase.Results;
        },
        enableBleScan,
        enableLanScan
      );
      if (!started) {
        this.prompt().showToast({ message: $r('app.string.toast_scan_start_failed') });
        this.phase = InventoryUiPhase.Results;
      }
    } catch (_err) {
      this.phase = InventoryUiPhase.Results;
      this.prompt().showToast({ message: $r('app.string.toast_action_failed') });
    } finally {
      this.actionInFlight = false;
    }
  }

  private stopScan(): void {
    HomeInventoryCoordinator.stop(true);
    this.phase = InventoryUiPhase.Results;
  }

  private syncPageAreaFromChange(width: number, height: number): void {
    if (width > 0 && height > 0) {
      this.pageAreaWidth = width;
      this.pageAreaHeight = height;
      this.syncPageOrientation(width, height);
    }
  }

  onWindowMetricsChanged(): void {
    if (this.mainWindowWidth > 0 && this.mainWindowHeight > 0) {
      this.applyPageLandscape(this.mainWindowWidth, this.mainWindowHeight);
    } else {
      this.applyPageLandscape(this.pageAreaWidth, this.pageAreaHeight);
    }
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
  pageHeader() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('‹')
          .fontSize(22)
          .fontColor(AppleTheme.PRIMARY)
      }
      .width(40)
      .height(40)
      .backgroundColor(AppleTheme.CANVAS)
      .border({ width: 1, color: AppleTheme.HAIRLINE })
      .accessibilityText($r('app.string.a11y_back'))
      .onClick(() => {
        router.back();
      })
      Blank()
        .layoutWeight(1)
      Text($r('app.string.inventory_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
      Blank()
        .layoutWeight(1)
      Blank()
        .width(40)
    }
    .width('100%')
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
  rescanButton() {
    Button($r('app.string.btn_start_scan'))
      .fontSize(AppleTheme.FONT_BODY)
      .fontColor(AppleTheme.CANVAS)
      .backgroundColor(AppleTheme.PRIMARY)
      .borderRadius(AppleTheme.RADIUS_PILL)
      .accessibilityText($r('app.string.a11y_rescan'))
      .onClick(() => {
        this.startInventoryScan().catch(() => {
          this.prompt().showToast({ message: $r('app.string.toast_action_failed') });
        });
      })
  }

  @Builder
  scanFooterIcon() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Text('■')
        .fontSize(16)
        .fontColor(AppleTheme.PRIMARY)
    }
    .width(48)
    .height(48)
    .backgroundColor(AppleTheme.CANVAS)
    .border({ width: 1, color: AppleTheme.PRIMARY })
    .accessibilityText($r('app.string.a11y_stop_scan'))
    .onClick(() => this.stopScan())
  }

  @Builder
  rescanFooterIcon() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Text('↻')
        .fontSize(20)
        .fontColor(AppleTheme.CANVAS)
    }
    .width(48)
    .height(48)
    .backgroundColor(AppleTheme.PRIMARY)
    .accessibilityText($r('app.string.a11y_rescan'))
    .onClick(() => {
      this.startInventoryScan().catch(() => {
        this.prompt().showToast({ message: $r('app.string.toast_action_failed') });
      });
    })
  }

  build() {
    Column({ space: 12 }) {
      this.pageHeader()
      HomeInventoryPanel({
        devices: this.devices,
        active: this.radarActive,
        scanning: this.phase === InventoryUiPhase.Scanning,
        isLandscapeLayout: this.pageLandscape,
        windowHeightVp: this.mainWindowHeightVp(),
        wifiSsid: this.wifiSsid,
        footerIconAction: this.phase === InventoryUiPhase.Scanning ? this.scanFooterIcon : this.rescanFooterIcon
      })
        .layoutWeight(1)
        .width('100%')

      if (!this.pageLandscape) {
        if (this.phase === InventoryUiPhase.Scanning) {
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
    .backgroundColor(AppleTheme.CANVAS)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onAreaChange((_old, area) => {
      this.syncPageAreaFromChange(area.width as number, area.height as number);
    })
  }

}
