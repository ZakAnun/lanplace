import { DeviceWorkbenchParams } from '../features/discovery/domain/DeviceWorkbenchParams';
import { HomeInventoryCoordinator } from '../features/discovery/data/HomeInventoryCoordinator';
import {
  HomeInventoryDevice,
  InventoryDeviceKind
} from '../features/discovery/domain/HomeInventoryDevice';
import { WorkbenchShell } from '../features/workbench/presentation/WorkbenchShell';

@Entry
@Component
struct DeviceWorkbench {
  @State deviceKey: string = '';
  @State kind: InventoryDeviceKind = InventoryDeviceKind.Ble;
  @State displayName: string = '';

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as DeviceWorkbenchParams;
    if (params === undefined) {
      return;
    }
    if (params.deviceKey.length > 0) {
      this.deviceKey = params.deviceKey;
    }
    this.resolveDeviceMeta();
  }

  private resolveDeviceMeta(): void {
    const snapshot: HomeInventoryDevice[] = HomeInventoryCoordinator.snapshotDevices();
    for (let i = 0; i < snapshot.length; i++) {
      if (snapshot[i].deviceKey === this.deviceKey) {
        this.kind = snapshot[i].kind;
        this.displayName = snapshot[i].displayName;
        return;
      }
    }
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
        displayName: this.displayName
      })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
