import { AppleTheme } from '../../../shared/theme/AppleTheme';
import { GattCharacteristicNode, GattServiceNode } from '../domain/GattProfile';
import { GattFacade } from '../domain/GattFacade';
import { GattServiceTree } from './GattServiceTree';
import { GattCharacteristicPanel } from './GattCharacteristicPanel';

@Component
export struct GattTabContent {
  @Prop deviceId: string = '';
  @State services: GattServiceNode[] = [];
  @State panelOpen: boolean = false;
  @State selectedService: string = '';
  @State selectedChar: string = '';
  @State canRead: boolean = false;
  @State canWrite: boolean = false;
  @State canWriteNoResponse: boolean = false;
  @State canNotify: boolean = false;
  @State canIndicate: boolean = false;
  @State panelSlot: number = 0;

  aboutToAppear(): void {
    this.services = GattFacade.profile(this.deviceId);
  }

  private selectedKey(): string {
    if (!this.panelOpen) {
      return '';
    }
    return `${this.selectedService}|${this.selectedChar}`;
  }

  private findCharacteristic(serviceUuid: string, characteristicUuid: string): GattCharacteristicNode | null {
    for (let i = 0; i < this.services.length; i++) {
      if (this.services[i].serviceUuid !== serviceUuid) {
        continue;
      }
      const chars: GattCharacteristicNode[] = this.services[i].characteristics;
      for (let j = 0; j < chars.length; j++) {
        if (chars[j].characteristicUuid === characteristicUuid) {
          return chars[j];
        }
      }
    }
    return null;
  }

  private openCharacteristic(serviceUuid: string, characteristicUuid: string): void {
    const node: GattCharacteristicNode | null = this.findCharacteristic(serviceUuid, characteristicUuid);
    if (node === null) {
      return;
    }
    this.selectedService = node.serviceUuid;
    this.selectedChar = node.characteristicUuid;
    this.canRead = node.canRead;
    this.canWrite = node.canWrite;
    this.canWriteNoResponse = node.canWriteNoResponse;
    this.canNotify = node.canNotify;
    this.canIndicate = node.canIndicate;
    this.panelSlot = this.panelSlot === 0 ? 1 : 0;
    this.panelOpen = true;
  }

  @Builder
  characteristicPanel() {
    GattCharacteristicPanel({
      deviceId: this.deviceId,
      serviceUuid: this.selectedService,
      characteristicUuid: this.selectedChar,
      canRead: this.canRead,
      canWrite: this.canWrite,
      canWriteNoResponse: this.canWriteNoResponse,
      canNotify: this.canNotify,
      canIndicate: this.canIndicate
    })
  }

  build() {
    Column({ space: 12 }) {
      if (this.services.length === 0) {
        Text($r('app.string.gatt_services_empty'))
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      } else {
        GattServiceTree({
          services: this.services,
          selectedKey: this.selectedKey(),
          onSelect: (serviceUuid: string, characteristicUuid: string): void => {
            this.openCharacteristic(serviceUuid, characteristicUuid);
          }
        })
      }
      if (this.panelOpen && this.panelSlot === 0) {
        this.characteristicPanel()
      } else if (this.panelOpen && this.panelSlot === 1) {
        this.characteristicPanel()
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
