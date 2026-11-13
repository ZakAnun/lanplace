import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

const BLUETOOTH_PERMISSION: Permissions = 'ohos.permission.ACCESS_BLUETOOTH';

export class BluetoothPermissionAskResult {
  granted: boolean = false;
  dialogShown: boolean = true;
}

export class PermissionHelper {
  static async hasBluetoothPermission(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const status = await atManager.checkAccessToken(
      context.applicationInfo.accessTokenId,
      BLUETOOTH_PERMISSION
    );
    return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }

  static async requestBluetoothPermission(context: common.UIAbilityContext): Promise<BluetoothPermissionAskResult> {
    const atManager = abilityAccessCtrl.createAtManager();
    const result = await atManager.requestPermissionsFromUser(context, [BLUETOOTH_PERMISSION]);
    const outcome = new BluetoothPermissionAskResult();
    outcome.granted = result.authResults.length > 0 &&
      result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    if (result.dialogShownResults !== undefined && result.dialogShownResults.length > 0) {
      outcome.dialogShown = result.dialogShownResults[0];
    }
    return outcome;
  }

  static async requestBluetoothPermissionFromSetting(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const settingResult = await atManager.requestPermissionOnSetting(context, [BLUETOOTH_PERMISSION]);
    return settingResult.length > 0 &&
      settingResult[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }
}
