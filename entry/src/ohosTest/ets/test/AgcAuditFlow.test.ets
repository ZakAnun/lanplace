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
    await driver.waitForComponent(matcher, FIND_TIMEOUT_MS);
    return true;
  } catch (_err) {
    return false;
  }
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
