import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { UIAbility, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

let abilityDelegator: abilityDelegatorRegistry.AbilityDelegator;
let abilityDelegatorArguments: abilityDelegatorRegistry.AbilityDelegatorArgs;
const tag: string = 'testTag';

async function onAbilityCreateCallback(data: UIAbility) {
  hilog.info(0x0000, tag, 'onAbilityCreateCallback, data: ${}', JSON.stringify(data));
}

async function addAbilityMonitorCallback(err: BusinessError) {
  hilog.info(0x0000, tag, 'addAbilityMonitorCallback : %{public}s', JSON.stringify(err) ?? '');
}

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare() {
    hilog.info(0x0000, tag, '%{public}s', 'OpenHarmonyTestRunner OnPrepare');
  }

  async onRun() {
    hilog.info(0x0000, tag, '%{public}s', 'OpenHarmonyTestRunner onRun run');
    abilityDelegatorArguments = abilityDelegatorRegistry.getArguments();
    abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
    const moduleName = abilityDelegatorArguments.parameters['-m'];
    const bundleName = abilityDelegatorArguments.bundleName;
    const testAbilityName: string = 'TestAbility';
    const lMonitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: testAbilityName,
      onAbilityCreate: onAbilityCreateCallback,
      moduleName: moduleName
    };
    abilityDelegator.addAbilityMonitor(lMonitor, addAbilityMonitorCallback);
    const want: Want = {
      bundleName: bundleName,
      abilityName: testAbilityName,
      moduleName: moduleName
    };
    abilityDelegator.startAbility(want, (err: BusinessError) => {
      hilog.info(0x0000, tag, 'startAbility : err : %{public}s', JSON.stringify(err) ?? '');
    });
    hilog.info(0x0000, tag, '%{public}s', 'OpenHarmonyTestRunner onRun end');
  }
}
