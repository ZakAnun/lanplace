import { AppleTheme } from '../../../shared/theme/AppleTheme';
import { InventoryDeviceKind } from '../../discovery/domain/HomeInventoryDevice';
import { WorkbenchTabId, visibleTabs } from '../domain/WorkbenchTabPolicy';

@Component
export struct WorkbenchShell {
  @Prop deviceKey: string = '';
  @Prop kind: InventoryDeviceKind = InventoryDeviceKind.Ble;
  @Prop displayName: string = '';
  @State activeTab: WorkbenchTabId = WorkbenchTabId.Overview;
  @State gattConnected: boolean = false;

  private tabIds(): WorkbenchTabId[] {
    return visibleTabs(this.kind, this.gattConnected);
  }

  @Builder
  tabBar() {
    Scroll() {
      Row({ space: 6 }) {
        ForEach(this.tabIds(), (tab: WorkbenchTabId) => {
          Text(this.tabLabel(tab))
            .fontSize(13)
            .fontColor(this.activeTab === tab ? AppleTheme.PRIMARY : AppleTheme.INK_MUTED)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(this.activeTab === tab ? AppleTheme.ROW_SELECTED : AppleTheme.CANVAS)
            .borderRadius(AppleTheme.RADIUS_PILL)
            .onClick(() => {
              this.activeTab = tab;
            })
        }, (tab: WorkbenchTabId) => `${tab}`)
      }
      .padding({ left: 4, right: 4 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  private tabLabel(tab: WorkbenchTabId): Resource {
    if (tab === WorkbenchTabId.Overview) {
      return $r('app.string.workbench_tab_overview');
    }
    if (tab === WorkbenchTabId.Advert) {
      return $r('app.string.workbench_tab_advert');
    }
    if (tab === WorkbenchTabId.Gatt) {
      return $r('app.string.workbench_tab_gatt');
    }
    if (tab === WorkbenchTabId.Lan) {
      return $r('app.string.workbench_tab_lan');
    }
    return $r('app.string.workbench_tab_log');
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Text('‹').fontSize(22).fontColor(AppleTheme.PRIMARY)
        }
        .width(40)
        .height(40)
        .backgroundColor(AppleTheme.CANVAS)
        .border({ width: 1, color: AppleTheme.HAIRLINE })
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

      this.tabBar()

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
      .layoutWeight(1)
      .width('100%')
      .padding(8)
    }
    .padding({ left: 20, right: 20, top: 12, bottom: 24 })
    .width('100%')
    .height('100%')
    .backgroundColor(AppleTheme.CANVAS)
  }
}
