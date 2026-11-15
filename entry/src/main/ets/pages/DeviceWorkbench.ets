import { DeviceWorkbenchParams } from '../features/discovery/domain/DeviceWorkbenchParams';
import { HomeInventoryCoordinator } from '../features/discovery/data/HomeInventoryCoordinator';
import {
  HomeInventoryDevice,
  InventoryDeviceKind
} from '../features/discovery/domain/HomeInventoryDevice';
import { WorkbenchTabId } from '../features/workbench/domain/WorkbenchTabPolicy';
import { WorkbenchShell } from '../features/workbench/presentation/WorkbenchShell';

@Entry
@Component
struct DeviceWorkbench {
  @State deviceKey: string = '';
  @State kind: InventoryDeviceKind = InventoryDeviceKind.Ble;
  @State displayName: string = '';
  @State detailLine: string = '';
  @State extraLine: string = '';
  @State initialTab: WorkbenchTabId = WorkbenchTabId.Overview;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as DeviceWorkbenchParams;
    if (params === undefined) {
      return;
    }
    if (params.deviceKey.length > 0) {
      this.deviceKey = params.deviceKey;
    }
    if (params.initialTab !== undefined) {
      this.initialTab = params.initialTab;
    }
    this.resolveDeviceMeta();
  }

  private resolveDeviceMeta(): void {
    const snapshot: HomeInventoryDevice[] = HomeInventoryCoordinator.snapshotDevices();
    for (let i = 0; i < snapshot.length; i++) {
      if (snapshot[i].deviceKey === this.deviceKey) {
        this.kind = snapshot[i].kind;
        this.displayName = snapshot[i].displayName;
        this.detailLine = snapshot[i].detailLine;
        this.extraLine = snapshot[i].extraLine;
        return;
      }
    }
    this.detailLine = '';
    this.extraLine = '';
    if (this.deviceKey.indexOf('lan:') === 0) {
      this.kind = InventoryDeviceKind.Lan;
    } else {
      this.kind = InventoryDeviceKind.Ble;
    }
  }

  build() {
    Column() {
      WorkbenchShell({
        deviceKey: this.deviceKey,
        kind: this.kind,
        displayName: this.displayName,
        detailLine: this.detailLine,
        extraLine: this.extraLine,
        initialTab: this.initialTab
      })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
