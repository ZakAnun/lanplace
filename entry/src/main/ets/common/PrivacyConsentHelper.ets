import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { PRIVACY_ACCEPTED_KEY, PREFS_NAME, SKIP_INTRO_KEY } from './Constants';

export class PrivacyConsentHelper {
  private static async getPrefs(context: common.Context): Promise<preferences.Preferences> {
    return preferences.getPreferences(context, PREFS_NAME);
  }

  static async isPrivacyAccepted(context: common.Context): Promise<boolean> {
    const prefs = await PrivacyConsentHelper.getPrefs(context);
    return await prefs.get(PRIVACY_ACCEPTED_KEY, false) as boolean;
  }

  static async setPrivacyAccepted(context: common.Context, accepted: boolean): Promise<void> {
    const prefs = await PrivacyConsentHelper.getPrefs(context);
    await prefs.put(PRIVACY_ACCEPTED_KEY, accepted);
    await prefs.flush();
  }

  static async shouldSkipIntro(context: common.Context): Promise<boolean> {
    const prefs = await PrivacyConsentHelper.getPrefs(context);
    return await prefs.get(SKIP_INTRO_KEY, false) as boolean;
  }

  static async setSkipIntro(context: common.Context): Promise<void> {
    const prefs = await PrivacyConsentHelper.getPrefs(context);
    await prefs.put(SKIP_INTRO_KEY, true);
    await prefs.flush();
  }
}
