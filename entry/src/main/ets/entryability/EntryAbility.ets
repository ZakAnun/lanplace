import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppleTheme } from '../common/AppleTheme';
import { WindowLayoutStore } from '../common/WindowLayoutStore';
import { HomeInventoryCoordinator } from '../service/HomeInventoryCoordinator';

const DOMAIN = 0x0000;
const WINDOW_BG: string = '#FFF5F5F7';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private readonly onWindowSizeChange = (size: window.Size): void => {
    WindowLayoutStore.applySize(size.width, size.height);
  };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  private bindMainWindow(mainWindow: window.Window): void {
    this.mainWindow = mainWindow;
    try {
      mainWindow.setWindowBackgroundColor(WINDOW_BG);
      mainWindow.setWindowSystemBarProperties({
        statusBarContentColor: AppleTheme.INK,
        navigationBarContentColor: AppleTheme.INK
      });
      mainWindow.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set window chrome. Cause: %{public}s', JSON.stringify(err));
    }

    try {
      const rect = mainWindow.getWindowProperties().windowRect;
      WindowLayoutStore.applySize(rect.width, rect.height);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to read windowRect. Cause: %{public}s', JSON.stringify(err));
    }

    try {
      mainWindow.on('windowSizeChange', this.onWindowSizeChange);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to register windowSizeChange. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    try {
      const mainWindow = windowStage.getMainWindowSync();
      this.bindMainWindow(mainWindow);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'getMainWindowSync failed, fallback async. Cause: %{public}s', JSON.stringify(err));
      windowStage.getMainWindow((preErr, preWindow) => {
        if (!preErr.code && preWindow !== undefined) {
          this.bindMainWindow(preWindow);
        }
      });
    }

    windowStage.loadContent('pages/Home', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    if (this.mainWindow !== null) {
      try {
        this.mainWindow.off('windowSizeChange', this.onWindowSizeChange);
      } catch (_err) {
        // ignore
      }
      this.mainWindow = null;
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    HomeInventoryCoordinator.stopForBackground();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
