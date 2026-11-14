import { common } from '@kit.AbilityKit';
import { PromptAction } from '@kit.ArkUI';
import { AppleTheme } from '../shared/theme/AppleTheme';
import { BluetoothHelper } from '../shared/platform/BluetoothHelper';
import { PermissionHelper } from '../shared/platform/PermissionHelper';
import { nextBluetoothPermissionStep } from '../shared/platform/PermissionPurpose';
import { ScanUiLabels } from '../shared/platform/ScanUiLabels';
import { PrivacyConsentHelper } from '../shared/platform/PrivacyConsentHelper';
import { WifiNetworkHelper } from '../shared/platform/WifiNetworkHelper';
import { isLandscapeLayout } from '../shared/layout/RadarLayoutHelper';
import { WindowLayoutStore } from '../shared/layout/WindowLayoutStore';
import { HomeInventoryPanel } from '../features/discovery/presentation/HomeInventoryPanel';
import { HomeInventoryDevice } from '../features/discovery/domain/HomeInventoryDevice';
import { BleScanCoordinator } from '../features/discovery/data/BleScanCoordinator';
import { HomeInventoryCoordinator } from '../features/discovery/data/HomeInventoryCoordinator';
import { ScanFilter, ScanFilterHolder } from '../features/advert/domain/ScanFilter';

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
  @State filterUuid: string = '';
  @State filterMfg: string = '';
  @State filterConnectableOnly: boolean = false;
  @State pageAreaWidth: number = 0;
  @State pageAreaHeight: number = 0;
  @State pageLandscape: boolean = false;
  @StorageLink(WindowLayoutStore.WIDTH_KEY) @Watch('onWindowMetricsChanged') mainWindowWidth: number = 0;
  @StorageLink(WindowLayoutStore.HEIGHT_KEY) @Watch('onWindowMetricsChanged') mainWindowHeight: number = 0;
  private actionInFlight: boolean = false;
  private pageAlive: boolean = true;
  private bluetoothAskAttempted: boolean = false;

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
    ScanUiLabels.load(this.abilityContext());
    this.restoreScanFilterFields();
    this.syncPageOrientation(this.pageAreaWidth, this.pageAreaHeight);
    this.refreshWifiSsid();
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

  private restoreScanFilterFields(): void {
    const filter: ScanFilter = ScanFilterHolder.current();
    this.filterUuid = filter.serviceUuid !== undefined ? filter.serviceUuid : '';
    this.filterMfg = filter.manufacturerId !== undefined ? filter.manufacturerId : '';
    this.filterConnectableOnly = filter.connectableOnly;
  }

  private applyScanFilter(): void {
    const next: ScanFilter = {
      serviceUuid: this.filterUuid,
      manufacturerId: this.filterMfg,
      connectableOnly: this.filterConnectableOnly
    };
    ScanFilterHolder.set(next);
    this.devices = HomeInventoryCoordinator.snapshotDevices();
  }

  private async refreshWifiSsid(): Promise<void> {
    this.wifiSsid = await WifiNetworkHelper.linkedSsid();
  }

  private async ensureBluetoothPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (await PermissionHelper.hasBluetoothPermission(context)) {
      return true;
    }
    const ask = await PermissionHelper.requestBluetoothPermission(context);
    if (ask.granted) {
      return true;
    }
    const step = nextBluetoothPermissionStep(ask.granted, ask.dialogShown, this.bluetoothAskAttempted);
    this.bluetoothAskAttempted = true;
    if (step === 'wait') {
      this.prompt().showToast({ message: $r('app.string.toast_bluetooth_permission') });
      return false;
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
    const granted = await PermissionHelper.requestBluetoothPermissionFromSetting(context);
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
        this.getUIContext().getRouter().back();
        return;
      }

      const useMockBle = BleScanCoordinator.useMockScan();
      const btGranted = await this.ensureBluetoothPermission(context);
      if (!this.pageAlive) {
        return;
      }

      let enableBleScan = btGranted;
      if (btGranted && !useMockBle && !BluetoothHelper.isEnabled()) {
        this.prompt().showToast({ message: $r('app.string.toast_bluetooth_off') });
        enableBleScan = false;
      }

      await this.refreshWifiSsid();
      if (!this.pageAlive) {
        return;
      }
      let enableLanScan = useMockBle ? true : WifiNetworkHelper.isWifiLinked();
      if (!enableLanScan && !useMockBle && enableBleScan) {
        this.prompt().showToast({ message: $r('app.string.toast_wifi_only_ble') });
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

  private openDeviceWorkbench(deviceKey: string): void {
    if (deviceKey.length === 0) {
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/DeviceWorkbench',
      params: { deviceKey: deviceKey }
    }).catch(() => {
      this.prompt().showToast({ message: $r('app.string.toast_action_failed') });
    });
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
        this.getUIContext().getRouter().back();
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
  scanFilterBar() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        TextInput({ placeholder: $r('app.string.inventory_filter_uuid'), text: $filterUuid })
          .layoutWeight(1)
          .height(36)
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK)
          .placeholderColor(AppleTheme.INK_MUTED)
          .backgroundColor(AppleTheme.CANVAS)
          .border({ width: 1, color: AppleTheme.HAIRLINE })
          .borderRadius(AppleTheme.RADIUS_LG)
          .padding({ left: 10, right: 10 })
          .accessibilityText($r('app.string.inventory_a11y_filter_uuid'))
          .onChange((value: string) => {
            this.filterUuid = value;
            this.applyScanFilter();
          })
        TextInput({ placeholder: $r('app.string.inventory_filter_mfg'), text: $filterMfg })
          .layoutWeight(1)
          .height(36)
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK)
          .placeholderColor(AppleTheme.INK_MUTED)
          .backgroundColor(AppleTheme.CANVAS)
          .border({ width: 1, color: AppleTheme.HAIRLINE })
          .borderRadius(AppleTheme.RADIUS_LG)
          .padding({ left: 10, right: 10 })
          .accessibilityText($r('app.string.inventory_a11y_filter_mfg'))
          .onChange((value: string) => {
            this.filterMfg = value;
            this.applyScanFilter();
          })
      }
      .width('100%')
      Row({ space: 8 }) {
        Toggle({ type: ToggleType.Switch, isOn: $filterConnectableOnly })
          .selectedColor(AppleTheme.PRIMARY)
          .accessibilityText($r('app.string.inventory_a11y_filter_connectable'))
          .onChange((isOn: boolean) => {
            this.filterConnectableOnly = isOn;
            this.applyScanFilter();
          })
        Text($r('app.string.inventory_filter_connectable'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .layoutWeight(1)
      }
      .width('100%')
      .height(AppleTheme.TOUCH_TARGET_VP)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
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
  landscapeScanStopButton() {
    Button($r('app.string.btn_stop_scan'))
      .fontSize(AppleTheme.FONT_BODY)
      .fontColor(AppleTheme.PRIMARY)
      .backgroundColor(AppleTheme.CANVAS)
      .border({ width: 1, color: AppleTheme.PRIMARY })
      .borderRadius(AppleTheme.RADIUS_PILL)
      .width('100%')
      .accessibilityText($r('app.string.a11y_stop_scan'))
      .onClick(() => this.stopScan())
  }

  @Builder
  landscapeRescanButton() {
    Button($r('app.string.btn_start_scan'))
      .fontSize(AppleTheme.FONT_BODY)
      .fontColor(AppleTheme.CANVAS)
      .backgroundColor(AppleTheme.PRIMARY)
      .borderRadius(AppleTheme.RADIUS_PILL)
      .width('100%')
      .accessibilityText($r('app.string.a11y_rescan'))
      .onClick(() => {
        this.startInventoryScan().catch(() => {
          this.prompt().showToast({ message: $r('app.string.toast_action_failed') });
        });
      })
  }

  @LocalBuilder
  landscapeScanAction() {
    if (this.phase === InventoryUiPhase.Scanning) {
      this.landscapeScanStopButton()
    } else {
      this.landscapeRescanButton()
    }
  }

  build() {
    Column({ space: 12 }) {
      this.pageHeader()
      this.scanFilterBar()
      HomeInventoryPanel({
        devices: this.devices,
        active: this.radarActive,
        scanning: this.phase === InventoryUiPhase.Scanning,
        isLandscapeLayout: this.pageLandscape,
        windowHeightVp: this.mainWindowHeightVp(),
        wifiSsid: this.wifiSsid,
        landscapeScanAction: this.landscapeScanAction,
        onOpenWorkbench: (deviceKey: string): void => {
          this.openDeviceWorkbench(deviceKey);
        }
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
