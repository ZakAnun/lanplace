#!/usr/bin/env node
/**
 * 本地复刻 RadarLayoutHelper 单测逻辑（无需模拟器），用于横屏改版快速验收。
 * 与 entry/src/test/RadarLayoutHelper.test.ets 断言一致。
 */
import { readFileSync } from 'node:fs';
const MIN_RADAR = 200;
const MAX_RADAR = 420;
const LANDSCAPE_RIGHT_RAIL_WIDTH = 176;
const LANDSCAPE_RADAR_INSET_VP = 16;

function isLandscapeLayout(width, height) {
  return width > height;
}

function radarZoneWidth(panelWidth, landscape) {
  if (!landscape || panelWidth <= 0) return panelWidth;
  const gap = 12;
  return Math.max(160, panelWidth - LANDSCAPE_RIGHT_RAIL_WIDTH - gap);
}

function computeLandscapeLeftChromeVp(showPickerEntry) {
  if (showPickerEntry) {
    return LANDSCAPE_RADAR_INSET_VP;
  }
  return LANDSCAPE_RADAR_INSET_VP;
}

function clampRadar(value) {
  return Math.max(MIN_RADAR, Math.min(MAX_RADAR, value));
}

function computeRadarCanvasSize(radarZoneWidth, height, landscape, showPickerEntry = false) {
  if (radarZoneWidth <= 0 || height <= 0) return 280;
  const reserveVertical = landscape ? computeLandscapeLeftChromeVp(showPickerEntry) : 128;
  const byWidth = radarZoneWidth - 16;
  const byHeight = height - reserveVertical;
  return clampRadar(Math.min(byWidth, byHeight));
}

let failed = 0;
function ok(name, cond) {
  if (!cond) {
    console.error('FAIL:', name);
    failed++;
  } else {
    console.log('OK:', name);
  }
}

ok('isLandscapeLayout', isLandscapeLayout(800, 400) && !isLandscapeLayout(400, 800));
ok('radarZoneWidth portrait', radarZoneWidth(360, false) === 360);
ok(
  'radarZoneWidth landscape',
  radarZoneWidth(800, true) === 800 - LANDSCAPE_RIGHT_RAIL_WIDTH - 12
);

const portraitSize = computeRadarCanvasSize(500, 900, false);
ok('portrait clamp', portraitSize >= 200 && portraitSize <= 420);

ok(
  'landscape chrome ignores picker',
  computeLandscapeLeftChromeVp(false) === LANDSCAPE_RADAR_INSET_VP &&
    computeLandscapeLeftChromeVp(true) === LANDSCAPE_RADAR_INSET_VP
);

const shortH = 380;
const withPicker = computeRadarCanvasSize(300, shortH, true, true);
const withoutPicker = computeRadarCanvasSize(300, shortH, true, false);
ok('landscape radar ignores picker height', withPicker === withoutPicker);

// 横屏典型高度：有列表入口时雷达不应吃掉全部高度（避免旧 72vp  Reserve）
const phoneLandscapeH = 360;
const zoneW = radarZoneWidth(780, true);
const radarH = computeRadarCanvasSize(zoneW, phoneLandscapeH, true, true);
const chrome = computeLandscapeLeftChromeVp(true);
ok('landscape total fits panel height', radarH + chrome <= phoneLandscapeH + 1);

// AGC 审核：右侧详情轨宽度与 AgcAuditLayout.test.ets 一致
ok('agc audit right rail width', LANDSCAPE_RIGHT_RAIL_WIDTH === 176);
ok('agc audit radar min visible', radarH >= 160);
ok(
  'landscape zones do not overlap',
  zoneW + 12 + LANDSCAPE_RIGHT_RAIL_WIDTH <= 780 + 1 && zoneW >= 160
);

const homeSource = readFileSync(
  new URL('../entry/src/main/ets/pages/Home.ets', import.meta.url),
  'utf8'
);
const portraitButtonStart = homeSource.indexOf('idlePrimaryButton()');
const portraitButtonEnd = homeSource.indexOf('idleLandscape', portraitButtonStart + 1);
const portraitButton = homeSource.slice(portraitButtonStart, portraitButtonEnd);

ok(
  'home drops private landscape metrics',
  !homeSource.includes('HOME_LANDSCAPE_RAIL_WIDTH') &&
    !homeSource.includes('HOME_LANDSCAPE_VERTICAL_RESERVE_VP')
);
ok(
  'home landscape uses shared rail',
  homeSource.includes('LANDSCAPE_RIGHT_RAIL_WIDTH') &&
    homeSource.includes('idleLandscapeHeader()') &&
    !homeSource.includes('idleLandscapeIconRail')
);
ok('portrait home button hugs text', !portraitButton.includes(".width('100%')"));
ok('portrait home body remains', homeSource.includes('idlePortraitBody()'));

const inventorySource = readFileSync(
  new URL('../entry/src/main/ets/pages/HomeInventory.ets', import.meta.url),
  'utf8'
);
const portraitStop = inventorySource.slice(
  inventorySource.indexOf('scanStopButton()'),
  inventorySource.indexOf('rescanButton()')
);

ok(
  'landscape scan action reads phase',
  inventorySource.includes('landscapeScanAction() {') &&
    inventorySource.includes('this.phase === InventoryUiPhase.Scanning') &&
    !inventorySource.includes('? this.landscapeScanStopButton : this.landscapeRescanButton')
);
ok('portrait stop button hugs text', !portraitStop.includes(".width('100%')"));

const layoutSource = readFileSync(
  new URL('../entry/src/main/ets/common/RadarDeviceLayout.ets', import.meta.url),
  'utf8'
);
ok('stable sphere helper exists', layoutSource.includes('deviceSpherePointForStableKey'));

const radarSource = readFileSync(
  new URL('../entry/src/main/ets/components/InventoryDiscoveryRadar.ets', import.meta.url),
  'utf8'
);
ok('canvas fallback skips hub links', !radarSource.includes('this.drawHubLinks('));
ok(
  'inventory radar hosts Component3D',
  radarSource.includes('Component3D(') &&
    radarSource.includes('Scene.load') &&
    radarSource.includes('raycast')
);

console.log('---');
console.log(failed === 0 ? 'All local layout checks passed.' : `${failed} check(s) failed.`);
process.exit(failed ? 1 : 0);
