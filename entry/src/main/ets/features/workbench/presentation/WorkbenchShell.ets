import { AppleTheme } from '../../../shared/theme/AppleTheme';
import {
  LANDSCAPE_RIGHT_RAIL_WIDTH,
  isLandscapeLayout
} from '../../../shared/layout/RadarLayoutHelper';
import { InventoryDeviceKind } from '../../discovery/domain/HomeInventoryDevice';
import { parseBleDeviceId } from '../../discovery/domain/DeviceWorkbenchParams';
import {
  GATT_ERROR_MAX_CONNECTIONS,
  GattFacade,
  gattErrorCode
} from '../../gatt/domain/GattFacade';
import { GattPhaseListener, GattSessionPhase } from '../../gatt/domain/GattSessionPhase';
import { WorkbenchTabId, visibleTabs } from '../domain/WorkbenchTabPolicy';
import {
  WorkbenchShellState,
  applyConnectionPhase,
  applyOpenGattDebug,
  createWorkbenchShellState,
  deriveConnectable,
  selectWorkbenchTab
} from '../domain/WorkbenchShellState';
import { WorkbenchSegmentedBar } from './WorkbenchSegmentedBar';
import { OverviewTab } from './tabs/OverviewTab';
import { AdvertTab } from './tabs/AdvertTab';
import { GattTab } from './tabs/GattTab';
import { LanTab } from './tabs/LanTab';
import { LogTab } from './tabs/LogTab';

@Component
export struct WorkbenchShell {
  @Prop deviceKey: string = '';
  @Prop kind: InventoryDeviceKind = InventoryDeviceKind.Ble;
  @Prop displayName: string = '';
  @Prop detailLine: string = '';
  @Prop extraLine: string = '';
  @Prop initialTab: WorkbenchTabId = WorkbenchTabId.Overview;
  @State activeTab: WorkbenchTabId = WorkbenchTabId.Overview;
  @State gattConnected: boolean = false;
  @State linkLost: boolean = false;
  @State gattConnecting: boolean = false;
  @State connectable: boolean = true;
  @State pageLandscape: boolean = false;
  private phaseListener: GattPhaseListener | null = null;

  aboutToAppear(): void {
    const state: WorkbenchShellState = createWorkbenchShellState(
      this.deviceKey,
      this.kind,
      this.displayName,
      deriveConnectable(this.kind),
      this.initialTab
    );
    this.connectable = state.connectable;
    this.gattConnected = state.gattConnected;
    this.linkLost = state.linkLost;
    this.activeTab = state.activeTab;
    if (this.phaseListener !== null) {
      GattFacade.unsubscribePhase(this.phaseListener);
    }
    const listener: GattPhaseListener = (deviceId: string, phase: GattSessionPhase): void => {
      this.onRemotePhase(deviceId, phase);
    };
    this.phaseListener = listener;
    GattFacade.subscribePhase(listener);
  }

  aboutToDisappear(): void {
    if (this.phaseListener !== null) {
      GattFacade.unsubscribePhase(this.phaseListener);
      this.phaseListener = null;
    }
  }

  private tabIds(): WorkbenchTabId[] {
    return visibleTabs(this.kind, this.gattConnected);
  }

  private applyAreaSize(width: number, height: number): void {
    if (width > 0 && height > 0) {
      this.pageLandscape = isLandscapeLayout(width, height);
    }
  }

  private snapshot(): WorkbenchShellState {
    const state: WorkbenchShellState = {
      deviceKey: this.deviceKey,
      kind: this.kind,
      displayName: this.displayName,
      connectable: this.connectable,
      gattConnected: this.gattConnected,
      linkLost: this.linkLost,
      activeTab: this.activeTab
    };
    return state;
  }

  private onRemotePhase(deviceId: string, phase: GattSessionPhase): void {
    const mine: string | undefined = parseBleDeviceId(this.deviceKey);
    if (mine === undefined || mine !== deviceId) {
      return;
    }
    const next: WorkbenchShellState = applyConnectionPhase(this.snapshot(), phase);
    this.gattConnected = next.gattConnected;
    this.linkLost = next.linkLost;
    this.activeTab = next.activeTab;
    this.gattConnecting = phase === 'Connecting';
  }

  private onSelectTab(tab: WorkbenchTabId): void {
    this.activeTab = selectWorkbenchTab(this.snapshot(), tab).activeTab;
  }

  private onOpenGattDebug(): void {
    this.activeTab = applyOpenGattDebug(this.gattConnected, this.activeTab);
  }

  private onConnect(): void {
    if (this.gattConnecting || this.gattConnected) {
      return;
    }
    const deviceId: string | undefined = parseBleDeviceId(this.deviceKey);
    if (deviceId === undefined) {
      return;
    }
    this.gattConnecting = true;
    GattFacade.connect(deviceId).then((): void => {
      this.gattConnecting = false;
      const next: WorkbenchShellState = applyConnectionPhase(this.snapshot(), GattFacade.phase(deviceId));
      this.gattConnected = next.gattConnected;
      this.linkLost = next.linkLost;
      this.activeTab = next.activeTab;
      if (!next.gattConnected) {
        return;
      }
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.workbench_connected')
      });
    }).catch((err: Object): void => {
      this.gattConnecting = false;
      this.gattConnected = GattFacade.isConnected(deviceId);
      this.linkLost = GattFacade.phase(deviceId) === 'Lost';
      if (gattErrorCode(err) === GATT_ERROR_MAX_CONNECTIONS) {
        this.getUIContext().getPromptAction().showToast({
          message: $r('app.string.toast_gatt_max_connections')
        });
        return;
      }
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.toast_action_failed')
      });
    });
  }

  private onDisconnect(): void {
    const deviceId: string | undefined = parseBleDeviceId(this.deviceKey);
    if (deviceId === undefined) {
      return;
    }
    GattFacade.disconnect(deviceId).then((): void => {
      this.gattConnecting = false;
      this.gattConnected = false;
      this.linkLost = false;
      if (this.activeTab === WorkbenchTabId.Gatt) {
        this.activeTab = WorkbenchTabId.Overview;
      }
    }).catch((): void => {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.toast_action_failed')
      });
    });
  }

  @Builder
  pageHeader() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('‹').fontSize(22).fontColor(AppleTheme.PRIMARY)
      }
      .width(40)
      .height(40)
      .backgroundColor(AppleTheme.CANVAS)
      .border({ width: 1, color: AppleTheme.HAIRLINE })
      .accessibilityText($r('app.string.a11y_back'))
      .onClick(() => {
        this.getUIContext().getRouter().back();
      })
      if (this.displayName.length > 0) {
        Text(this.displayName)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppleTheme.INK)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Text($r('app.string.workbench_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppleTheme.INK)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      Blank().width(40)
    }
    .width('100%')
  }

  private tabUsesOuterScroll(): boolean {
    return this.activeTab !== WorkbenchTabId.Log;
  }

  @Builder
  tabScrollHost() {
    if (this.tabUsesOuterScroll()) {
      Scroll() {
        Column() {
          this.tabContent()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ bottom: 12 })
      }
      .scrollBar(BarState.Auto)
      .width('100%')
      .layoutWeight(1)
      .constraintSize({ minHeight: 0 })
    } else {
      Column() {
        this.tabContent()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .constraintSize({ minHeight: 0 })
    }
  }

  @Builder
  tabContent() {
    if (this.activeTab === WorkbenchTabId.Overview) {
      OverviewTab({
        kind: this.kind,
        displayName: this.displayName,
        detailLine: this.detailLine,
        connectable: this.connectable,
        gattConnected: this.gattConnected,
        linkLost: this.linkLost,
        connecting: this.gattConnecting,
        onConnect: (): void => {
          this.onConnect();
        },
        onDisconnect: (): void => {
          this.onDisconnect();
        },
        onOpenGattDebug: (): void => {
          this.onOpenGattDebug();
        }
      })
    } else if (this.activeTab === WorkbenchTabId.Advert) {
      AdvertTab({
        deviceKey: this.deviceKey
      })
    } else if (this.activeTab === WorkbenchTabId.Gatt) {
      GattTab({
        deviceKey: this.deviceKey
      })
    } else if (this.activeTab === WorkbenchTabId.Lan) {
      LanTab({
        deviceKey: this.deviceKey,
        detailLine: this.detailLine,
        extraLine: this.extraLine
      })
    } else if (this.activeTab === WorkbenchTabId.Log) {
      LogTab({
        deviceKey: this.deviceKey,
        kind: this.kind
      })
    } else {
      Column({ space: 8 }) {
        Text($r('app.string.workbench_placeholder_body'))
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.INK_MUTED)
        if (this.deviceKey.length > 0) {
          Text(this.deviceKey)
            .fontSize(AppleTheme.FONT_CAPTION)
            .fontColor(AppleTheme.INK_MUTED)
            .fontFamily('HarmonyOS Sans')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(8)
    }
  }

  @Builder
  portraitBody() {
    Column({ space: 12 }) {
      WorkbenchSegmentedBar({
        tabs: this.tabIds(),
        activeTab: this.activeTab,
        landscape: false,
        kind: this.kind,
        onSelect: (tab: WorkbenchTabId): void => {
          this.onSelectTab(tab);
        }
      })
      this.tabScrollHost()
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  landscapeBody() {
    Row({ space: 12 }) {
      WorkbenchSegmentedBar({
        tabs: this.tabIds(),
        activeTab: this.activeTab,
        landscape: true,
        kind: this.kind,
        onSelect: (tab: WorkbenchTabId): void => {
          this.onSelectTab(tab);
        }
      })
        .width(LANDSCAPE_RIGHT_RAIL_WIDTH)
        .height('100%')
      Column() {
        this.tabScrollHost()
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column({ space: 12 }) {
      this.pageHeader()
      if (this.pageLandscape) {
        this.landscapeBody()
      } else {
        this.portraitBody()
      }
    }
    .padding({ left: 20, right: 20, top: 12, bottom: 24 })
    .width('100%')
    .height('100%')
    .backgroundColor(AppleTheme.CANVAS)
    .onAreaChange((_old, area) => {
      this.applyAreaSize(area.width as number, area.height as number);
    })
  }
}
