import { common, Want } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppleTheme } from '../common/AppleTheme';
import { PRIVACY_POLICY_URL } from '../common/Constants';
import { PermissionHelper } from '../common/PermissionHelper';
import { PrivacyConsentHelper } from '../common/PrivacyConsentHelper';
import { BleScanService } from '../service/BleScanService';
import { ScannedDevice } from '../model/ScannedDevice';
import { DeviceListItem } from '../components/DeviceListItem';
import { PrivacyConsentDialog } from '../components/PrivacyConsentDialog';

enum UiPhase {
  Intro,
  Idle,
  Scanning,
  Results
}

@Entry
@Component
struct Home {
  @State phase: UiPhase = UiPhase.Intro;
  @State introPulse: number = 0.6;
  @State introScale: number = 0.85;
  @State devices: ScannedDevice[] = [];
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private privacyDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.privacyDialogController = new CustomDialogController({
      builder: PrivacyConsentDialog({
        onAgree: () => {
          this.privacyDialogController?.close();
          PrivacyConsentHelper.setPrivacyAccepted(this.context, true).then(() => {
            this.beginScanFlow();
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
    PrivacyConsentHelper.shouldSkipIntro(this.context).then((skip: boolean) => {
      if (skip) {
        this.phase = UiPhase.Idle;
      } else {
        this.runIntroAnimation();
      }
    });
  }

  aboutToDisappear(): void {
    BleScanService.stop();
  }

  private runIntroAnimation(): void {
    animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
      this.introScale = 1;
      this.introPulse = 1;
    });
    setTimeout(() => {
      animateTo({ duration: 600, curve: Curve.EaseInOut }, () => {
        this.introPulse = 0.3;
      });
      setTimeout(() => {
        this.phase = UiPhase.Idle;
      }, 600);
    }, 700);
  }

  private skipIntro(): void {
    PrivacyConsentHelper.setSkipIntro(this.context).then(() => {
      this.phase = UiPhase.Idle;
    });
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

  private async onPrimaryAction(): Promise<void> {
    const accepted = await PrivacyConsentHelper.isPrivacyAccepted(this.context);
    if (!accepted) {
      this.privacyDialogController?.open();
      return;
    }
    await this.beginScanFlow();
  }

  private async beginScanFlow(): Promise<void> {
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
        promptAction.showToast({ message: '未授予蓝牙权限' });
        return;
      }
    }
    this.phase = UiPhase.Scanning;
    this.devices = [];
    try {
      BleScanService.start((list: ScannedDevice[]) => {
        this.devices = list;
        if (list.length > 0) {
          this.phase = UiPhase.Results;
        }
      });
    } catch (e) {
      promptAction.showToast({ message: `${e}` });
      this.phase = UiPhase.Idle;
      return;
    }
    setTimeout(() => {
      if (BleScanService.isScanning()) {
        BleScanService.stop();
      }
      if (this.devices.length > 0) {
        this.phase = UiPhase.Results;
      } else if (this.phase === UiPhase.Scanning) {
        this.phase = UiPhase.Results;
      }
    }, 30100);
  }

  private stopScan(): void {
    BleScanService.stop();
    this.phase = UiPhase.Results;
  }

  @Builder
  introView() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppleTheme.PARCHMENT)
      Column({ space: 24 }) {
        Circle()
          .width(120)
          .height(120)
          .fill(AppleTheme.PRIMARY)
          .opacity(this.introPulse)
          .scale({ x: this.introScale, y: this.introScale })
        Circle()
          .width(180)
          .height(180)
          .fill(Color.Transparent)
          .border({ width: 2, color: AppleTheme.PRIMARY })
          .opacity(this.introPulse * 0.5)
          .scale({ x: this.introScale, y: this.introScale })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height('100%')
      Button($r('app.string.btn_skip_intro'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.PRIMARY)
        .backgroundColor(Color.Transparent)
        .position({ x: '80%', y: 48 })
        .onClick(() => this.skipIntro())
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  idleView() {
    Column({ space: 24 }) {
      Text($r('app.string.home_title'))
        .fontSize(AppleTheme.FONT_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
        .letterSpacing(-0.5)
      Text($r('app.string.home_subtitle'))
        .fontSize(AppleTheme.FONT_BODY)
        .fontColor(AppleTheme.INK_MUTED)
        .lineHeight(25)
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
    .padding({ left: 32, right: 32, top: 80, bottom: 48 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppleTheme.PARCHMENT)
  }

  @Builder
  scanningView() {
    Column({ space: 16 }) {
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
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  deviceList() {
    if (this.devices.length === 0) {
      Text($r('app.string.empty_list'))
        .fontSize(AppleTheme.FONT_CAPTION)
        .fontColor(AppleTheme.INK_MUTED)
        .margin({ top: 24 })
    } else {
      List({ space: 12 }) {
        ForEach(this.devices, (item: ScannedDevice) => {
          ListItem() {
            DeviceListItem({ device: item })
          }
        }, (item: ScannedDevice) => item.deviceId)
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
        .onClick(() => this.onPrimaryAction())
    }
    .padding(24)
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppleTheme.CANVAS)
  }

  build() {
    Column() {
      if (this.phase === UiPhase.Intro) {
        this.introView()
      } else if (this.phase === UiPhase.Idle) {
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
