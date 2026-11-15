import { parseBleDeviceId } from '../../../discovery/domain/DeviceWorkbenchParams';
import { GattTabContent } from '../../../gatt/presentation/GattTabContent';

@Component
export struct GattTab {
  @Prop deviceKey: string = '';

  private deviceId(): string {
    const parsed: string | undefined = parseBleDeviceId(this.deviceKey);
    if (parsed === undefined) {
      return '';
    }
    return parsed;
  }

  build() {
    GattTabContent({
      deviceId: this.deviceId()
    })
  }
}
