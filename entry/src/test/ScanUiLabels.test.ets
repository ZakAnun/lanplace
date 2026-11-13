import { describe, it, expect } from '@ohos/hypium';
import { ScanUiLabels } from '../main/ets/common/ScanUiLabels';

export default function scanUiLabelsTest() {
  describe('ScanUiLabels', () => {
    it('pickerA11yFormatsEnglishTemplate', 0, () => {
      ScanUiLabels.a11yPickLan = '%1$s, LAN';
      ScanUiLabels.a11yPickBle = '%1$s, Bluetooth';
      expect(ScanUiLabels.pickerA11y('Printer', true)).assertEqual('Printer, LAN');
      expect(ScanUiLabels.pickerA11y('Band', false)).assertEqual('Band, Bluetooth');
    });
    it('connectableLabelFollowsLocaleFields', 0, () => {
      ScanUiLabels.connectable = 'Connectable';
      ScanUiLabels.broadcastOnly = 'Broadcast only';
      expect(ScanUiLabels.connectableLabel(true)).assertEqual('Connectable');
      expect(ScanUiLabels.connectableLabel(false)).assertEqual('Broadcast only');
    });
  });
}
