import { AppleTheme } from '../../../shared/theme/AppleTheme';
import { bytesToHex, hexToBytes } from '../../../shared/ble/BytesHex';
import { GattFacade } from '../domain/GattFacade';
import { GattValueEvent, GattValueListener } from '../domain/GattProfile';
import { sigCharacteristicName } from '../domain/SigCharacteristicNames';

@Component
export struct GattCharacteristicPanel {
  @Prop deviceId: string = '';
  @Prop serviceUuid: string = '';
  @Prop characteristicUuid: string = '';
  @Prop canRead: boolean = false;
  @Prop canWrite: boolean = false;
  @Prop canWriteNoResponse: boolean = false;
  @Prop canNotify: boolean = false;
  @Prop canIndicate: boolean = false;
  @State valueHex: string = '';
  @State hexInput: string = '';
  @State notifyOn: boolean = false;
  private disposed: boolean = false;
  private notifyBusy: boolean = false;
  private readonly onValue: GattValueListener = (event: GattValueEvent): void => {
    this.showValue(event);
  };

  aboutToAppear(): void {
    this.disposed = false;
    GattFacade.subscribeValues(this.onValue);
    if (this.canRead) {
      this.readOnce();
    }
  }

  aboutToDisappear(): void {
    this.disposed = true;
    GattFacade.unsubscribeValues(this.onValue);
  }

  private title(): string {
    const name: string = sigCharacteristicName(this.characteristicUuid);
    if (name.length > 0) {
      return name;
    }
    return this.characteristicUuid;
  }

  private canSubscribe(): boolean {
    return this.canNotify || this.canIndicate;
  }

  private canSend(): boolean {
    return this.canWrite || this.canWriteNoResponse;
  }

  private showValue(event: GattValueEvent): void {
    if (this.disposed) {
      return;
    }
    if (event.deviceId !== this.deviceId || event.serviceUuid !== this.serviceUuid) {
      return;
    }
    if (event.characteristicUuid !== this.characteristicUuid) {
      return;
    }
    this.valueHex = bytesToHex(event.value);
  }

  private toast(message: Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  private readOnce(): void {
    GattFacade.readCharacteristicValue(this.deviceId, this.serviceUuid, this.characteristicUuid)
      .then((value: Uint8Array): void => {
        if (this.disposed) {
          return;
        }
        this.valueHex = bytesToHex(value);
      })
      .catch((): void => {
        if (this.disposed) {
          return;
        }
        this.toast($r('app.string.gatt_error_read'));
      });
  }

  private writeHex(): void {
    let payload: Uint8Array;
    try {
      payload = hexToBytes(this.hexInput);
    } catch (_err) {
      this.toast($r('app.string.gatt_error_invalid_hex'));
      return;
    }
    GattFacade.writeCharacteristicValue(this.deviceId, this.serviceUuid, this.characteristicUuid, payload)
      .catch((): void => {
        if (this.disposed) {
          return;
        }
        this.toast($r('app.string.gatt_error_write'));
      });
  }

  private applyNotify(isOn: boolean): void {
    if (this.notifyBusy) {
      return;
    }
    this.notifyBusy = true;
    const previous: boolean = this.notifyOn;
    this.notifyOn = isOn;
    GattFacade.setCharacteristicChangeNotification(
      this.deviceId,
      this.serviceUuid,
      this.characteristicUuid,
      isOn
    ).then((): void => {
      this.notifyBusy = false;
    }).catch((): void => {
      this.notifyBusy = false;
      if (this.disposed) {
        return;
      }
      this.notifyOn = previous;
      this.toast($r('app.string.gatt_error_notify'));
    });
  }

  build() {
    Column({ space: 8 }) {
      Text(this.title())
        .fontSize(AppleTheme.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppleTheme.INK)
        .width('100%')
      if (this.valueHex.length > 0) {
        Text(this.valueHex)
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .fontFamily('HarmonyOS Sans')
          .width('100%')
      } else {
        Text($r('app.string.gatt_value_empty'))
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK_MUTED)
          .width('100%')
      }
      if (this.canRead) {
        Button($r('app.string.gatt_read'))
          .type(ButtonType.Normal)
          .width('100%')
          .height(AppleTheme.TOUCH_TARGET_VP)
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.PRIMARY)
          .backgroundColor(AppleTheme.CANVAS)
          .border({ width: 1, color: AppleTheme.PRIMARY })
          .borderRadius(AppleTheme.RADIUS_PILL)
          .onClick(() => {
            this.readOnce();
          })
      }
      if (this.canSend()) {
        TextInput({ placeholder: $r('app.string.gatt_write_hex'), text: this.hexInput })
          .width('100%')
          .height(36)
          .fontSize(AppleTheme.FONT_CAPTION)
          .fontColor(AppleTheme.INK)
          .placeholderColor(AppleTheme.INK_MUTED)
          .backgroundColor(AppleTheme.CANVAS)
          .border({ width: 1, color: AppleTheme.HAIRLINE })
          .borderRadius(AppleTheme.RADIUS_LG)
          .padding({ left: 10, right: 10 })
          .accessibilityText($r('app.string.gatt_write_hex'))
          .onChange((value: string) => {
            this.hexInput = value;
          })
        Button($r('app.string.gatt_write_hex'))
          .type(ButtonType.Normal)
          .width('100%')
          .height(AppleTheme.TOUCH_TARGET_VP)
          .fontSize(AppleTheme.FONT_BODY)
          .fontColor(AppleTheme.CANVAS)
          .backgroundColor(AppleTheme.PRIMARY)
          .borderRadius(AppleTheme.RADIUS_PILL)
          .onClick(() => {
            this.writeHex();
          })
      }
      if (this.canSubscribe()) {
        Row() {
          Text($r('app.string.gatt_notify'))
            .fontSize(AppleTheme.FONT_BODY)
            .fontColor(AppleTheme.INK)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.notifyOn })
            .selectedColor(AppleTheme.PRIMARY)
            .onChange((isOn: boolean) => {
              this.applyNotify(isOn);
            })
        }
        .width('100%')
        .constraintSize({ minHeight: AppleTheme.TOUCH_TARGET_VP })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(8)
    .border({ width: 1, color: AppleTheme.HAIRLINE })
    .borderRadius(AppleTheme.RADIUS_LG)
  }
}
