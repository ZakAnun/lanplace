/**
 * 仪器化 UI：覆盖审核员主路径 — 隐私同意 → 首页 → 附近设备 → 扫描控制按钮可见。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { Driver, ON, On, DisplayRotation } from '@ohos.UiTest';

const BUNDLE = 'com.lanplace.bluescopes';
const ENTRY_MODULE = 'entry';
const UI_WAIT_MS = 800;
const PAGE_WAIT_MS = 4000;
const FIND_TIMEOUT_MS = 12000;

class UiCopy {
  agree: string = '同意并继续';
  discover: string = '发现附近设备';
  nearby: string = '附近设备';
  appName: string = '蓝域';
  privacy: string = '隐私';
  caption: string = '发现周围蓝牙与当前 Wi‑Fi 网络设备';
  stop: string = '停止扫描';
  start: string = '开始扫描';
  rescan: string = '再次扫描';
  picker: string = '从列表选择设备';
  tapHint: string = '点击光点查看设备信息';
  chooseDevice: string = '选择设备';
  close: string = '关闭';
  back: string = '返回';
  ble: string = '蓝牙';
}

function englishCopy(): UiCopy {
  const copy = new UiCopy();
  copy.agree = 'Agree and continue';
  copy.discover = 'Find nearby devices';
  copy.nearby = 'Nearby devices';
  copy.appName = 'BlueScopes';
  copy.privacy = 'Privacy';
  copy.caption = 'Find nearby Bluetooth and Wi-Fi devices';
  copy.stop = 'Stop scan';
  copy.start = 'Start scan';
  copy.rescan = 'Scan again';
  copy.picker = 'Choose from list';
  copy.tapHint = 'Tap a dot to view device info';
  copy.chooseDevice = 'Choose a device';
  copy.close = 'Close';
  copy.back = 'Back';
  copy.ble = 'Bluetooth';
  return copy;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function existThenClick(driver: Driver, matcher: On): Promise<boolean> {
  return existThenClickWithin(driver, matcher, FIND_TIMEOUT_MS);
}

async function existThenClickWithin(driver: Driver, matcher: On, timeoutMs: number): Promise<boolean> {
  try {
    await driver.waitForComponent(matcher, timeoutMs);
    const comp = await driver.findComponent(matcher);
    await comp.click();
    await driver.delayMs(UI_WAIT_MS);
    return true;
  } catch (_err) {
    return false;
  }
}

async function allowBluetoothIfShown(driver: Driver): Promise<void> {
  const labels: string[] = ['允许', 'Allow', '使用期间允许', '仅在使用该应用时允许'];
  for (let i = 0; i < labels.length; i++) {
    if (await existThenClickWithin(driver, ON.text(labels[i]), 1200)) {
      return;
    }
  }
}

async function componentExists(driver: Driver, matcher: On): Promise<boolean> {
  try {
    const comp = await driver.waitForComponent(matcher, FIND_TIMEOUT_MS);
    return comp != null;
  } catch (_err) {
    return false;
  }
}

async function componentExistsWithin(driver: Driver, matcher: On, timeoutMs: number): Promise<boolean> {
  try {
    const comp = await driver.waitForComponent(matcher, timeoutMs);
    return comp != null;
  } catch (_err) {
    return false;
  }
}

async function waitUntilAbsent(driver: Driver, text: string, timeoutMs: number): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const present = await componentExistsWithin(driver, ON.text(text), 500);
    if (!present) {
      return true;
    }
    await sleep(350);
  }
  return false;
}

const MOCK_DEVICE_NAMES: string[] = [
  '客厅温湿度计',
  'Mi Band Demo',
  'Beacon-Gateway',
  '未知设备',
  '键盘 K380',
  '客厅电视 (Cast)',
  '书房打印机'
];

async function clickFirstListedDevice(driver: Driver): Promise<boolean> {
  for (let i = 0; i < MOCK_DEVICE_NAMES.length; i++) {
    const name = MOCK_DEVICE_NAMES[i];
    if (await componentExistsWithin(driver, ON.text(name), 800)) {
      return await existThenClick(driver, ON.text(name));
    }
  }
  return false;
}

async function anyMockDeviceVisible(driver: Driver): Promise<boolean> {
  for (let i = 0; i < MOCK_DEVICE_NAMES.length; i++) {
    if (await componentExistsWithin(driver, ON.text(MOCK_DEVICE_NAMES[i]), 400)) {
      return true;
    }
  }
  return false;
}

async function ensureInventoryPage(driver: Driver, copy: UiCopy): Promise<void> {
  if (await componentExists(driver, ON.text(copy.nearby))) {
    return;
  }
  await existThenClick(driver, ON.text(copy.agree));
  await sleep(PAGE_WAIT_MS);
  await existThenClick(driver, ON.text(copy.discover));
  await sleep(PAGE_WAIT_MS);
  await existThenClick(driver, ON.text(copy.start));
  await allowBluetoothIfShown(driver);
  await sleep(PAGE_WAIT_MS);
}

async function rotateToLandscape(driver: Driver): Promise<void> {
  await driver.setDisplayRotationEnabled(true);
  await driver.setDisplayRotation(DisplayRotation.ROTATION_90);
  await driver.delayMs(PAGE_WAIT_MS);
}

export default function agcAuditFlowTest() {
  describe('AgcAuditFlow', () => {
    let driver: Driver;
    let copy: UiCopy = new UiCopy();

    beforeAll(async (done: Function) => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({
        bundleName: BUNDLE,
        abilityName: 'EntryAbility',
        moduleName: ENTRY_MODULE
      });
      await sleep(PAGE_WAIT_MS);
      driver = await Driver.create();
      const englishUi = await componentExistsWithin(driver, ON.text('Agree and continue'), 2500) ||
        await componentExistsWithin(driver, ON.text('Find nearby devices'), 800);
      if (englishUi) {
        copy = englishCopy();
      }
      done();
    });

    afterAll(async (done: Function) => {
      try {
        await driver.setDisplayRotation(DisplayRotation.ROTATION_0);
      } catch (_err) {
      }
      done();
    });

    it('homeOrPrivacyThenDiscoverEntry', 0, async (done: Function) => {
      await existThenClick(driver, ON.text(copy.agree));
      await sleep(PAGE_WAIT_MS);
      const hasDiscover = await componentExists(driver, ON.text(copy.discover));
      expect(hasDiscover).assertTrue();
      done();
    });

    it('homeLandscapeKeepsTitleRadarAndRightRail', 0, async (done: Function) => {
      await existThenClick(driver, ON.text(copy.agree));
      await sleep(PAGE_WAIT_MS);
      expect(await componentExists(driver, ON.text(copy.discover))).assertTrue();
      await rotateToLandscape(driver);
      const title = await driver.findComponent(ON.text(copy.appName));
      const action = await driver.findComponent(ON.text(copy.discover));
      const privacy = await driver.findComponent(ON.text(copy.privacy));
      const caption = await driver.findComponent(ON.text(copy.caption));
      const titleBounds = await title.getBounds();
      const actionBounds = await action.getBounds();
      const privacyBounds = await privacy.getBounds();
      const captionBounds = await caption.getBounds();
      expect(titleBounds.bottom <= actionBounds.top + 4).assertTrue();
      expect(actionBounds.left >= titleBounds.right - 4).assertTrue();
      expect(Math.abs(privacyBounds.left - actionBounds.left) < 48).assertTrue();
      expect(captionBounds.left + 8 >= actionBounds.left).assertTrue();
      expect(captionBounds.right <= actionBounds.right + 24).assertTrue();
      await driver.setDisplayRotation(DisplayRotation.ROTATION_0);
      await driver.delayMs(PAGE_WAIT_MS);
      done();
    });

    it('scanLabelStaysWithPhaseAcrossRotation', 0, async (done: Function) => {
      await driver.setDisplayRotation(DisplayRotation.ROTATION_0);
      await driver.delayMs(PAGE_WAIT_MS);
      await ensureInventoryPage(driver, copy);
      const alreadyScanning = await componentExists(driver, ON.text(copy.stop));
      if (!alreadyScanning) {
        expect(await existThenClick(driver, ON.text(copy.start))).assertTrue();
      }
      expect(await componentExists(driver, ON.text(copy.stop))).assertTrue();
      await rotateToLandscape(driver);
      const stopNow = await driver.findComponents(ON.text(copy.stop));
      const startNow = await driver.findComponents(ON.text(copy.start));
      expect(stopNow != null && stopNow.length > 0).assertTrue();
      expect(startNow == null || startNow.length === 0).assertTrue();
      await driver.waitForComponent(ON.text(copy.start), 40000);
      const stopLater = await driver.findComponents(ON.text(copy.stop));
      expect(stopLater == null || stopLater.length === 0).assertTrue();
      await driver.setDisplayRotation(DisplayRotation.ROTATION_0);
      await driver.delayMs(PAGE_WAIT_MS);
      expect(await componentExists(driver, ON.text(copy.start))).assertTrue();
      const stopPortrait = await driver.findComponents(ON.text(copy.stop));
      expect(stopPortrait == null || stopPortrait.length === 0).assertTrue();
      done();
    });

    it('inventoryScanControlsReachable', 0, async (done: Function) => {
      await existThenClick(driver, ON.text(copy.discover));
      await sleep(PAGE_WAIT_MS);
      await existThenClick(driver, ON.text(copy.start));
      await allowBluetoothIfShown(driver);
      await sleep(PAGE_WAIT_MS);
      const hasTitle = await componentExists(driver, ON.text(copy.nearby));
      expect(hasTitle).assertTrue();
      const hasStop = await componentExists(driver, ON.text(copy.stop));
      const hasRescan = await componentExists(driver, ON.text(copy.rescan));
      const hasStart = await componentExists(driver, ON.text(copy.start));
      expect(hasStop || hasRescan || hasStart).assertTrue();
      done();
    });

    it('sphereTapDragKeepsNearbyChrome', 0, async (done: Function) => {
      await driver.setDisplayRotation(DisplayRotation.ROTATION_0);
      await driver.delayMs(UI_WAIT_MS);
      await ensureInventoryPage(driver, copy);
      expect(await componentExists(driver, ON.text(copy.nearby))).assertTrue();

      if (!(await componentExistsWithin(driver, ON.text(copy.picker), 1500)) &&
        !(await componentExistsWithin(driver, ON.text(copy.stop), 800))) {
        await existThenClick(driver, ON.text(copy.start));
        await componentExistsWithin(driver, ON.text(copy.picker), FIND_TIMEOUT_MS);
      }

      const title = await driver.findComponent(ON.text(copy.nearby));
      const titleBounds = await title.getBounds();
      const midX = Math.round((titleBounds.left + titleBounds.right) / 2);
      const radarY = Math.round(titleBounds.bottom + 260);
      await driver.click(Math.max(0, midX), Math.max(0, radarY));

      let hintGone = await waitUntilAbsent(driver, copy.tapHint, FIND_TIMEOUT_MS);
      if (!hintGone) {
        const opened = await existThenClick(driver, ON.text(copy.picker));
        if (opened) {
          await componentExistsWithin(driver, ON.text(copy.chooseDevice), FIND_TIMEOUT_MS);
          await clickFirstListedDevice(driver);
          await sleep(UI_WAIT_MS);
        }
        hintGone = await waitUntilAbsent(driver, copy.tapHint, 4000);
      }
      const listVisible = await anyMockDeviceVisible(driver);
      expect(hintGone || listVisible).assertTrue();

      if (await componentExistsWithin(driver, ON.text(copy.chooseDevice), 800)) {
        await existThenClick(driver, ON.text(copy.close));
      }

      try {
        const panY = Math.round(titleBounds.bottom + 220);
        await driver.swipe(Math.max(8, midX), Math.max(0, panY), Math.max(8, midX) + 120, Math.max(0, panY), 700);
      } catch (_err) {
      }
      expect(await componentExists(driver, ON.text(copy.nearby))).assertTrue();
      const hasStop = await componentExists(driver, ON.text(copy.stop));
      const hasStart = await componentExists(driver, ON.text(copy.start));
      expect(hasStop || hasStart).assertTrue();
      const hasPicker = await componentExistsWithin(driver, ON.text(copy.picker), 2000);
      const hasEmpty = await componentExistsWithin(driver, ON.text(copy.tapHint), 1500);
      expect(hasPicker || hasEmpty || hintGone).assertTrue();
      if (await componentExistsWithin(driver, ON.text(copy.chooseDevice), 800)) {
        await existThenClick(driver, ON.text(copy.close));
      }
      const backed = await existThenClick(driver, ON.text(copy.back));
      if (!backed) {
        await existThenClick(driver, ON.text('‹'));
      }
      await driver.setDisplayRotation(DisplayRotation.ROTATION_0);
      done();
    });

    it('landscapeKeepsScanControlsAndRightDetail', 0, async (done: Function) => {
      await ensureInventoryPage(driver, copy);
      await rotateToLandscape(driver);
      const rotation = await driver.getDisplayRotation();
      expect(rotation === DisplayRotation.ROTATION_90).assertTrue();

      expect(await componentExists(driver, ON.text(copy.nearby))).assertTrue();
      const hasStop = await componentExists(driver, ON.text(copy.stop));
      const hasStart = await componentExists(driver, ON.text(copy.start));
      expect(hasStop || hasStart).assertTrue();
      const stopNow = await driver.findComponents(ON.text(copy.stop));
      const actionLabel = (stopNow != null && stopNow.length > 0) ? copy.stop : copy.start;
      const action = await driver.findComponent(ON.text(actionLabel));
      const detail = await driver.findComponent(ON.text(copy.tapHint));
      const legend = await driver.findComponent(ON.text(copy.ble));
      const actionBounds = await action.getBounds();
      const detailBounds = await detail.getBounds();
      const legendBounds = await legend.getBounds();
      expect(detailBounds.top >= actionBounds.bottom - 4).assertTrue();
      expect(Math.abs(detailBounds.left - actionBounds.left) < 48).assertTrue();
      expect(legendBounds.left + 24 >= actionBounds.left).assertTrue();
      expect(actionBounds.right <= detailBounds.right + 24).assertTrue();
      done();
    });
  });
}
