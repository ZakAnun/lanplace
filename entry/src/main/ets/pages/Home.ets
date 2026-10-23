import { common, Want } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppleTheme } from '../common/AppleTheme';
import { PRIVACY_POLICY_URL } from '../common/Constants';
import { PermissionHelper } from '../common/PermissionHelper';
import { PrivacyConsentHelper } from '../common/PrivacyConsentHelper';
import { BluetoothHelper } from '../common/BluetoothHelper';
import { BleScanService } from '../service/BleScanService';
import { ScannedDevice } from '../model/ScannedDevice';
import { DeviceListItem } from '../components/DeviceListItem';
import { PrivacyConsentDialog } from '../components/PrivacyConsentDialog';
import { BleDiscoveryRadar } from '../components/BleDiscoveryRadar';

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
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private privacyDialogController: CustomDialogController | null = null;
  private actionInFlight: boolean = false;

  aboutToAppear(): void {
    this.privacyDialogController = new CustomDialogController({
      builder: PrivacyConsentDialog({
        onAgree: () => {
          this.privacyDialogController?.close();
          PrivacyConsentHelper.setPrivacyAccepted(this.context, true).then(() => {
            this.beginScanFlow().catch(() => {
              promptAction.showToast({ message: '操作失败，请重试' });
            });
          }).catch(() => {
            promptAction.showToast({ message: '无法保存隐私同意状态' });
          });
        },
        onDecline: () => {
          this.privacyDialogController?.close();
          this.context.terminateSelf();
        },
        onOpenPolicy: () => {
          this.openPrivacyPolicy();
        }
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center
    });
    PrivacyConsentHelper.isPrivacyAccepted(this.context).then((accepted) => {
      if (!accepted) {
        this.privacyDialogController?.open();
      }
    }).catch(() => {
      // ignore prefs read errors on first launch
    });
  }

  aboutToDisappear(): void {
    BleScanService.stop({ emitUpdate: false, notifyComplete: false });
  }

  onPageHide(): void {
    if (BleScanService.isScanning()) {
      BleScanService.stop({ emitUpdate: true, notifyComplete: true });
      this.phase = UiPhase.Results;
    }
  }

  private openPrivacyPolicy(): void {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: PRIVACY_POLICY_URL
    };
    this.context.startAbility(want).catch(() => {
      promptAction.showToast({ message: '无法打开隐私政策链接' });
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
    if (this.actionInFlight || BleScanService.isScanning()) {
      promptAction.showToast({ message: '正在扫描中' });
      return;
    }
    try {
      this.actionInFlight = true;
      const accepted = await PrivacyConsentHelper.isPrivacyAccepted(this.context);
      if (!accepted) {
        this.privacyDialogController?.open();
        return;
      }
      await this.beginScanFlow();
    } catch (_err) {
      promptAction.showToast({ message: '操作失败，请重试' });
    } finally {
      this.actionInFlight = false;
    }
  }

  private async beginScanFlow(): Promise<void> {
    if (BleScanService.isScanning()) {
      promptAction.showToast({ message: '正在扫描中' });
      return;
    }
    if (!BluetoothHelper.isEnabled()) {
      promptAction.showToast({ message: '请先开启系统蓝牙' });
      return;
    }
    const hasBt = await PermissionHelper.hasBluetoothPermission(this.context);
    if (!hasBt) {
      const ok = await promptAction.showDialog({
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
      const granted = await PermissionHelper.requestBluetoothPermission(this.context);
      if (!granted) {
        promptAction.showToast({ message: '未授予蓝牙权限，可在系统设置中开启' });
        return;
      }
    }
    this.phase = UiPhase.Scanning;
    this.devices = [];
    try {
      const started = BleScanService.start(
        (list: ScannedDevice[]) => {
          this.devices = list;
        },
        () => {
          this.phase = UiPhase.Results;
        }
      );
      if (!started) {
        promptAction.showToast({ message: '正在扫描中' });
        this.phase = UiPhase.Idle;
      }
    } catch (e) {
      promptAction.showToast({ message: this.scanErrorMessage(e as Error) });
      this.phase = UiPhase.Idle;
    }
  }

  private stopScan(): void {
    BleScanService.stop({ emitUpdate: true, notifyComplete: true });
    this.phase = UiPhase.Results;
  }

  private deviceListKey(item: ScannedDevice): string {
    return `${item.deviceId}_${item.rssi}_${item.displayName}_${item.advertSummary}`;
  }

  @Builder
  idleView() {
    Column({ space: 20 }) {
      BleDiscoveryRadar({ active: true })
      Text($r('app.string.home_title'))
        .fontSize(AppleTheme.FONT_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
        .letterSpacing(-0.5)
      Text($r('app.string.home_subtitle'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.INK_MUTED)
        .lineHeight(25)
        .textAlign(TextAlign.Center)
      Button($r('app.string.btn_view_devices'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.CANVAS)
        .backgroundColor(AppleTheme.PRIMARY)
        .borderRadius(AppleTheme.RADIUS_PILL)
        .padding({ left: 22, right: 22, top: 11, bottom: 11 })
        .onClick(() => {
          this.onPrimaryAction();
        })
      Text('隐私政策')
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.PRIMARY)
        .onClick(() => this.openPrivacyPolicy())
    }
    .padding({ left: 24, right: 24, top: 48, bottom: 48 })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppleTheme.PARCHMENT)
  }

  @Builder
  scanningView() {
    Column({ space: 16 }) {
      BleDiscoveryRadar({ active: true })
      Row({ space: 12 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(AppleTheme.PRIMARY)
        Text($r('app.string.scanning_hint'))
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.INK)
      }
      Button($r('app.string.btn_stop_scan'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.PRIMARY)
        .backgroundColor(AppleTheme.CANVAS)
        .border({ width: 1, color: AppleTheme.PRIMARY })
        .borderRadius(AppleTheme.RADIUS_PILL)
        .onClick(() => this.stopScan())
      this.deviceList()
    }
    .padding(24)
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppleTheme.PARCHMENT)
  }

  @Builder
  deviceList() {
    if (this.devices.length === 0) {
      Text($r('app.string.empty_list'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .margin({ top: 8 })
        .width('100%')
    } else {
      List({ space: 12 }) {
        ForEach(this.devices, (item: ScannedDevice) => {
          ListItem() {
            DeviceListItem({ device: item })
          }
        }, (item: ScannedDevice) => this.deviceListKey(item))
      }
      .width('100%')
      .layoutWeight(1)
    }
  }

  @Builder
  resultsView() {
    Column({ space: 16 }) {
      Text($r('app.string.home_title'))
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
      this.deviceList()
      Button($r('app.string.btn_view_devices'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.CANVAS)
        .backgroundColor(AppleTheme.PRIMARY)
        .borderRadius(AppleTheme.RADIUS_PILL)
        .onClick(() => {
          this.onPrimaryAction();
        })
    }
    .padding(24)
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppleTheme.CANVAS)
  }

  build() {
    Column() {
      if (this.phase === UiPhase.Idle) {
        this.idleView()
      } else if (this.phase === UiPhase.Scanning) {
        this.scanningView()
      } else {
        this.resultsView()
      }
    }
    .width('100%')
    .height('100%')
  }
}
