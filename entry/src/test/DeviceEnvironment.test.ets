import { describe, it, expect } from '@ohos/hypium';
import { isSimulatorProductHint } from '../main/ets/common/DeviceEnvironment';

export default function deviceEnvironmentTest() {
  describe('DeviceEnvironment', () => {
    it('isSimulatorProductHint_emulator', 0, () => {
      expect(isSimulatorProductHint('emulator')).assertTrue();
      expect(isSimulatorProductHint('Emulator-X86')).assertTrue();
    });

    it('isSimulatorProductHint_phone', 0, () => {
      expect(isSimulatorProductHint('Mate 60 Pro')).assertFalse();
      expect(isSimulatorProductHint('')).assertFalse();
    });
  });
}
