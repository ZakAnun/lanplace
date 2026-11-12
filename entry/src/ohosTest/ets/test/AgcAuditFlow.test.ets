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

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function existThenClick(driver: Driver, matcher: On): Promise<boolean> {
  try {
    await driver.waitForComponent(matcher, FIND_TIMEOUT_MS);
    const comp = await driver.findComponent(matcher);
    await comp.click();
    await driver.delayMs(UI_WAIT_MS);
    return true;
  } catch (_err) {
    return false;
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

async function ensureInventoryPage(driver: Driver): Promise<void> {
  if (await componentExists(driver, ON.text('附近设备'))) {
    return;
  }
  await existThenClick(driver, ON.text('同意并继续'));
  await sleep(PAGE_WAIT_MS);
  await existThenClick(driver, ON.text('发现附近设备'));
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

    beforeAll(async (done: Function) => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({
        bundleName: BUNDLE,
        abilityName: 'EntryAbility',
        moduleName: ENTRY_MODULE
      });
      await sleep(PAGE_WAIT_MS);
      driver = await Driver.create();
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
      await existThenClick(driver, ON.text('同意并继续'));
      await sleep(PAGE_WAIT_MS);
      const hasDiscover = await componentExists(driver, ON.text('发现附近设备'));
      expect(hasDiscover).assertTrue();
      done();
    });

    it('homeLandscapeKeepsTitleRadarAndRightRail', 0, async (done: Function) => {
      await existThenClick(driver, ON.text('同意并继续'));
      await sleep(PAGE_WAIT_MS);
      expect(await componentExists(driver, ON.text('发现附近设备'))).assertTrue();
      await rotateToLandscape(driver);
      const title = await driver.findComponent(ON.text('蓝域'));
      const action = await driver.findComponent(ON.text('发现附近设备'));
      const privacy = await driver.findComponent(ON.text('隐私'));
      const caption = await driver.findComponent(ON.text('发现周围蓝牙与当前 Wi‑Fi 网络设备'));
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
      await ensureInventoryPage(driver);
      const alreadyScanning = await componentExists(driver, ON.text('停止扫描'));
      if (!alreadyScanning) {
        expect(await existThenClick(driver, ON.text('开始扫描'))).assertTrue();
      }
      expect(await componentExists(driver, ON.text('停止扫描'))).assertTrue();
      await rotateToLandscape(driver);
      const stopNow = await driver.findComponents(ON.text('停止扫描'));
      const startNow = await driver.findComponents(ON.text('开始扫描'));
      expect(stopNow != null && stopNow.length > 0).assertTrue();
      expect(startNow == null || startNow.length === 0).assertTrue();
      await driver.waitForComponent(ON.text('开始扫描'), 40000);
      const stopLater = await driver.findComponents(ON.text('停止扫描'));
      expect(stopLater == null || stopLater.length === 0).assertTrue();
      await driver.setDisplayRotation(DisplayRotation.ROTATION_0);
      await driver.delayMs(PAGE_WAIT_MS);
      expect(await componentExists(driver, ON.text('开始扫描'))).assertTrue();
      const stopPortrait = await driver.findComponents(ON.text('停止扫描'));
      expect(stopPortrait == null || stopPortrait.length === 0).assertTrue();
      done();
    });

    it('inventoryScanControlsReachable', 0, async (done: Function) => {
      await existThenClick(driver, ON.text('发现附近设备'));
      await sleep(PAGE_WAIT_MS);
      const hasTitle = await componentExists(driver, ON.text('附近设备'));
      expect(hasTitle).assertTrue();
      const hasStop = await componentExists(driver, ON.text('停止扫描'));
      const hasRescan = await componentExists(driver, ON.text('再次扫描'));
      const hasStart = await componentExists(driver, ON.text('开始扫描'));
      expect(hasStop || hasRescan || hasStart).assertTrue();
      done();
    });

    it('sphereTapDragKeepsNearbyChrome', 0, async (done: Function) => {
      await driver.setDisplayRotation(DisplayRotation.ROTATION_0);
      await driver.delayMs(UI_WAIT_MS);
      await ensureInventoryPage(driver);
      expect(await componentExists(driver, ON.text('附近设备'))).assertTrue();

      if (!(await componentExistsWithin(driver, ON.text('从列表选择设备'), 1500)) &&
        !(await componentExistsWithin(driver, ON.text('停止扫描'), 800))) {
        await existThenClick(driver, ON.text('开始扫描'));
        await componentExistsWithin(driver, ON.text('从列表选择设备'), FIND_TIMEOUT_MS);
      }

      const title = await driver.findComponent(ON.text('附近设备'));
      const titleBounds = await title.getBounds();
      const midX = Math.round((titleBounds.left + titleBounds.right) / 2);
      const radarY = Math.round(titleBounds.bottom + 260);
      await driver.click(Math.max(0, midX), Math.max(0, radarY));

      let hintGone = await waitUntilAbsent(driver, '点击光点查看设备信息', FIND_TIMEOUT_MS);
      if (!hintGone) {
        const opened = await existThenClick(driver, ON.text('从列表选择设备'));
        if (opened) {
          await componentExistsWithin(driver, ON.text('选择设备'), FIND_TIMEOUT_MS);
          await clickFirstListedDevice(driver);
          await sleep(UI_WAIT_MS);
        }
        hintGone = await waitUntilAbsent(driver, '点击光点查看设备信息', 4000);
      }
      const listVisible = await anyMockDeviceVisible(driver);
      expect(hintGone || listVisible).assertTrue();

      if (await componentExistsWithin(driver, ON.text('选择设备'), 800)) {
        await existThenClick(driver, ON.text('关闭'));
      }

      try {
        const panY = Math.round(titleBounds.bottom + 220);
        await driver.swipe(Math.max(8, midX), Math.max(0, panY), Math.max(8, midX) + 120, Math.max(0, panY), 700);
      } catch (_err) {
      }
      expect(await componentExists(driver, ON.text('附近设备'))).assertTrue();
      const hasStop = await componentExists(driver, ON.text('停止扫描'));
      const hasStart = await componentExists(driver, ON.text('开始扫描'));
      expect(hasStop || hasStart).assertTrue();
      const hasPicker = await componentExistsWithin(driver, ON.text('从列表选择设备'), 2000);
      const hasEmpty = await componentExistsWithin(driver, ON.text('点击光点查看设备信息'), 1500);
      expect(hasPicker || hasEmpty || hintGone).assertTrue();
      if (await componentExistsWithin(driver, ON.text('选择设备'), 800)) {
        await existThenClick(driver, ON.text('关闭'));
      }
      const backed = await existThenClick(driver, ON.text('返回'));
      if (!backed) {
        await existThenClick(driver, ON.text('‹'));
      }
      await driver.setDisplayRotation(DisplayRotation.ROTATION_0);
      done();
    });

    it('landscapeKeepsScanControlsAndRightDetail', 0, async (done: Function) => {
      await ensureInventoryPage(driver);
      await rotateToLandscape(driver);
      const rotation = await driver.getDisplayRotation();
      expect(rotation === DisplayRotation.ROTATION_90).assertTrue();

      expect(await componentExists(driver, ON.text('附近设备'))).assertTrue();
      const hasStop = await componentExists(driver, ON.text('停止扫描'));
      const hasStart = await componentExists(driver, ON.text('开始扫描'));
      expect(hasStop || hasStart).assertTrue();
      const stopNow = await driver.findComponents(ON.text('停止扫描'));
      const actionLabel = (stopNow != null && stopNow.length > 0) ? '停止扫描' : '开始扫描';
      const action = await driver.findComponent(ON.text(actionLabel));
      const detail = await driver.findComponent(ON.text('点击光点查看设备信息'));
      const legend = await driver.findComponent(ON.text('蓝牙'));
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
