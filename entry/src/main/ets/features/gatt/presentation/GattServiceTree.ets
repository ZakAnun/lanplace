import { AppleTheme } from '../../../shared/theme/AppleTheme';
import { GattCharacteristicNode, GattServiceNode } from '../domain/GattProfile';
import { sigCharacteristicName } from '../domain/SigCharacteristicNames';

@Component
export struct GattServiceTree {
  @Prop services: GattServiceNode[] = [];
  @Prop selectedKey: string = '';
  onSelect: (serviceUuid: string, characteristicUuid: string) => void =
    (_serviceUuid: string, _characteristicUuid: string): void => {
    };

  private rowKey(serviceUuid: string, characteristicUuid: string): string {
    return `${serviceUuid}|${characteristicUuid}`;
  }

  private characteristicLabel(node: GattCharacteristicNode): string {
    const name: string = sigCharacteristicName(node.characteristicUuid);
    if (name.length > 0) {
      return name;
    }
    return node.characteristicUuid;
  }

  build() {
    List({ space: 8 }) {
      ForEach(this.services, (service: GattServiceNode) => {
        ListItem() {
          Column({ space: 6 }) {
            Text(service.serviceUuid)
              .fontSize(AppleTheme.FONT_CAPTION)
              .fontColor(AppleTheme.INK_MUTED)
              .fontFamily('HarmonyOS Sans')
              .width('100%')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            ForEach(service.characteristics, (item: GattCharacteristicNode) => {
              Row() {
                Text(this.characteristicLabel(item))
                  .fontSize(AppleTheme.FONT_BODY)
                  .fontColor(AppleTheme.INK)
                  .layoutWeight(1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .constraintSize({ minHeight: AppleTheme.TOUCH_TARGET_VP })
              .padding({ left: 8, right: 8 })
              .borderRadius(AppleTheme.RADIUS_LG)
              .backgroundColor(this.selectedKey === this.rowKey(service.serviceUuid, item.characteristicUuid) ?
                AppleTheme.ROW_SELECTED : AppleTheme.CANVAS)
              .onClick(() => {
                this.onSelect(service.serviceUuid, item.characteristicUuid);
              })
            }, (item: GattCharacteristicNode) => this.rowKey(service.serviceUuid, item.characteristicUuid))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(8)
          .border({ width: 1, color: AppleTheme.HAIRLINE })
          .borderRadius(AppleTheme.RADIUS_LG)
        }
      }, (service: GattServiceNode) => service.serviceUuid)
    }
    .scrollBar(BarState.Auto)
    .width('100%')
    .layoutWeight(1)
  }
}
