import { AppleTheme } from '../../../shared/theme/AppleTheme';
import { InventoryDeviceKind } from '../../discovery/domain/HomeInventoryDevice';
import { WorkbenchTabId } from '../domain/WorkbenchTabPolicy';

@Component
export struct WorkbenchSegmentedBar {
  @Prop tabs: WorkbenchTabId[] = [];
  @Prop activeTab: WorkbenchTabId = WorkbenchTabId.Overview;
  @Prop landscape: boolean = false;
  @Prop kind: InventoryDeviceKind = InventoryDeviceKind.Ble;
  onSelect: (tab: WorkbenchTabId) => void = (_tab: WorkbenchTabId): void => {
  };

  private selectedFg(): string {
    if (this.kind === InventoryDeviceKind.Lan) {
      return AppleTheme.LAN_TEXT;
    }
    return AppleTheme.PRIMARY;
  }

  private selectedBg(): string {
    if (this.kind === InventoryDeviceKind.Lan) {
      return AppleTheme.ROW_SELECTED_LAN;
    }
    return AppleTheme.ROW_SELECTED;
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

  @Builder
  tabChip(tab: WorkbenchTabId) {
    Text(this.tabLabel(tab))
      .fontSize(13)
      .fontColor(this.activeTab === tab ? this.selectedFg() : AppleTheme.INK_MUTED)
      .fontWeight(this.activeTab === tab ? FontWeight.Medium : FontWeight.Normal)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .constraintSize({ minHeight: AppleTheme.TOUCH_TARGET_VP })
      .textAlign(TextAlign.Center)
      .backgroundColor(this.activeTab === tab ? this.selectedBg() : AppleTheme.CANVAS)
      .borderRadius(AppleTheme.RADIUS_PILL)
      .width(this.landscape ? '100%' : 'auto')
      .onClick(() => {
        this.onSelect(tab);
      })
  }

  build() {
    if (this.landscape) {
      Scroll() {
        Column({ space: 6 }) {
          ForEach(this.tabs, (tab: WorkbenchTabId) => {
            this.tabChip(tab)
          }, (tab: WorkbenchTabId) => `${tab}`)
        }
        .width('100%')
        .padding({ left: 4, right: 4 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
    } else {
      Scroll() {
        Row({ space: 6 }) {
          ForEach(this.tabs, (tab: WorkbenchTabId) => {
            this.tabChip(tab)
          }, (tab: WorkbenchTabId) => `${tab}`)
        }
        .padding({ left: 4, right: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
  }
}
