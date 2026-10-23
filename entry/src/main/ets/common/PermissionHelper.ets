import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

const BLUETOOTH_PERMISSION: Permissions = 'ohos.permission.ACCESS_BLUETOOTH';

export class PermissionHelper {
  static async hasBluetoothPermission(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const status = await atManager.checkAccessToken(
      context.applicationInfo.accessTokenId,
      BLUETOOTH_PERMISSION
    );
    return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }

  static async requestBluetoothPermission(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const result = await atManager.requestPermissionsFromUser(context, [BLUETOOTH_PERMISSION]);
    return result.authResults.length > 0 && result.authResults[0] === 0;
  }
}
