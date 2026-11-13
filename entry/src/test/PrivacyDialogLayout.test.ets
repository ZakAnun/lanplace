import { describe, it, expect } from '@ohos/hypium';
import {
  PRIVACY_POLICY_URL,
  PRIVACY_POLICY_URL_EN,
  privacyPolicyUrlForLanguage
} from '../main/ets/common/Constants';
import {
  computePrivacyBodyScrollMaxHeightVp,
  computePrivacyDialogMaxHeightVp,
  privacyDialogChromeHeightVp,
  PRIVACY_BODY_SCROLL_MAX_CAP_VP,
  PRIVACY_BODY_SCROLL_MIN_VP,
  PRIVACY_DIALOG_OUTER_MARGIN_VP
} from '../main/ets/common/PrivacyDialogLayout';

export default function privacyDialogLayoutTest() {
  describe('PrivacyDialogLayout', () => {
    it('chromeHeightPositive', 0, () => {
      expect(privacyDialogChromeHeightVp() > 0).assertTrue();
    });

    it('tallWindowCapsScroll', 0, () => {
      expect(computePrivacyBodyScrollMaxHeightVp(800)).assertEqual(PRIVACY_BODY_SCROLL_MAX_CAP_VP);
    });

    it('unknownWindowUsesMinScroll', 0, () => {
      expect(computePrivacyBodyScrollMaxHeightVp(0)).assertEqual(PRIVACY_BODY_SCROLL_MIN_VP);
    });

    it('shortLandscapeKeepsButtonsOnScreen', 0, () => {
      const windowH = 360;
      const scrollH = computePrivacyBodyScrollMaxHeightVp(windowH);
      expect(scrollH >= 48).assertTrue();
      expect(scrollH < PRIVACY_BODY_SCROLL_MAX_CAP_VP).assertTrue();
      const used = privacyDialogChromeHeightVp() + scrollH + PRIVACY_DIALOG_OUTER_MARGIN_VP * 2;
      expect(used <= windowH + 1).assertTrue();
    });

    it('dialogMaxLeavesRoomForButtons', 0, () => {
      const windowH = 360;
      const dialogH = computePrivacyDialogMaxHeightVp(windowH);
      expect(dialogH + PRIVACY_DIALOG_OUTER_MARGIN_VP * 2 <= windowH + 1).assertTrue();
      expect(dialogH > privacyDialogChromeHeightVp()).assertTrue();
    });

    it('englishLocaleOpensEnglishPolicy', 0, () => {
      expect(privacyPolicyUrlForLanguage('en')).assertEqual(PRIVACY_POLICY_URL_EN);
      expect(privacyPolicyUrlForLanguage('en-US')).assertEqual(PRIVACY_POLICY_URL_EN);
    });

    it('chineseLocaleOpensChinesePolicy', 0, () => {
      expect(privacyPolicyUrlForLanguage('zh-Hans')).assertEqual(PRIVACY_POLICY_URL);
      expect(privacyPolicyUrlForLanguage('zh-CN')).assertEqual(PRIVACY_POLICY_URL);
      expect(privacyPolicyUrlForLanguage(undefined)).assertEqual(PRIVACY_POLICY_URL);
    });
  });
}
