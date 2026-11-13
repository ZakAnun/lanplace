#!/usr/bin/env node
/**
 * 本地复刻 RadarLayoutHelper 单测逻辑（无需模拟器），用于横屏改版快速验收。
 * 与 entry/src/test/RadarLayoutHelper.test.ets 断言一致。
 */
import { existsSync, readdirSync, readFileSync } from 'node:fs';
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
ok(
  'home page does not request bluetooth',
  !homeSource.includes('requestBluetoothPermission') &&
    !homeSource.includes('requestPermissionsFromUser') &&
    !homeSource.includes('BluetoothHelper')
);
const privacyAgreeBlock = homeSource.slice(
  homeSource.indexOf('onAgree:'),
  homeSource.indexOf('onDecline:')
);
ok(
  'privacy agree stays on home',
  privacyAgreeBlock.includes('setPrivacyAccepted') &&
    !privacyAgreeBlock.includes('openHomeInventory')
);
ok(
  'privacy policy url follows locale',
  homeSource.includes('privacyPolicyUrlForLanguage') &&
    homeSource.includes('config.language')
);

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

const cameraSource = readFileSync(
  new URL('../entry/src/main/ets/common/SphereCameraMath.ets', import.meta.url),
  'utf8'
);
ok('sphere facing helpers exist', cameraSource.includes('sphereFacing') && cameraSource.includes('pointFacingScale'));

const radarSource = readFileSync(
  new URL('../entry/src/main/ets/components/InventoryDiscoveryRadar.ets', import.meta.url),
  'utf8'
);
ok('canvas fallback skips hub links', !radarSource.includes('this.drawHubLinks('));
ok(
  'inventory radar hosts Component3D',
  radarSource.includes('Component3D(') &&
    radarSource.includes('Scene.load') &&
    radarSource.includes('pickNearestFrontKey')
);
ok(
  'radar applies facing appearance',
  radarSource.includes('applyPointAppearance') &&
    radarSource.includes('pointFacingScale') &&
    radarSource.includes('pointFacingAlpha')
);
ok(
  'radar selected ring overlay',
  radarSource.includes('selectedPointRing') &&
    radarSource.includes('worldToCanvas')
);
ok(
  'canvas draws far points first',
  radarSource.includes('items.sort((a, b) => a.z - b.z)')
);
ok(
  'inventory sphere uses field dots not rim',
  radarSource.includes('drawFieldPoint') &&
    radarSource.includes('createFieldCloud') &&
    !radarSource.includes('sphereRimOverlay') &&
    !radarSource.includes('centerHubOverlay')
);
ok(
  'golden field helper exists',
  layoutSource.includes('goldenSpherePoint')
);
ok(
  'orbit pan follows hand',
  cameraSource.includes('applyOrbitPan') &&
    cameraSource.includes('pitch + dyVp')
);
ok(
  'real-scan synthetic feed exists',
  readFileSync(new URL('../entry/src/main/ets/common/InventoryDeviceMerge.ets', import.meta.url), 'utf8')
    .includes('syntheticInventoryFeed')
);
ok(
  'canvas fallback can orbit by pan',
  radarSource.includes('canvasBranch()') &&
    radarSource.includes('this.stepOrbit(') &&
    (radarSource.split('PanGesture({ fingers: 1').length - 1) >= 2
);
ok(
  'pan ignores missing primary finger',
  cameraSource.includes('firstFingerLocalX') &&
    radarSource.includes('firstFingerLocalX(event.fingerList') &&
    !radarSource.includes('fingers[0].localX') &&
    !radarSource.includes('fingers[0].localY')
);

function firstFingerLocalX(fingers, fallback) {
  if (fingers == null) {
    return fallback;
  }
  for (let i = 0; i < fingers.length; i++) {
    const finger = fingers[i];
    if (finger != null) {
      return finger.localX;
    }
  }
  return fallback;
}

ok('pan fallback when finger list missing', firstFingerLocalX(undefined, 140) === 140);
ok('pan fallback when finger list empty', firstFingerLocalX([], 140) === 140);
ok(
  'Mate 80 hole at fingers[0] does not throw',
  firstFingerLocalX([undefined], 140) === 140 &&
    firstFingerLocalX([undefined, { localX: 18, localY: 24 }], 140) === 18
);

function isHuaweiPermissionReason(reason) {
  if (typeof reason !== 'string' || reason.length === 0 || reason.length > 256) {
    return false;
  }
  if (!(reason.endsWith('。') || reason.endsWith('.'))) {
    return false;
  }
  if (reason.includes('需要权限') || reason.includes('获取权限') || reason.includes('使用蓝牙。')) {
    return false;
  }
  return reason.includes('用于') || reason.startsWith('Used to');
}

function stringValue(doc, name) {
  const hit = (doc.string || []).find((item) => item.name === name);
  return hit ? hit.value : '';
}

const strings = JSON.parse(
  readFileSync(new URL('../entry/src/main/resources/base/element/string.json', import.meta.url), 'utf8')
);
const enStrings = JSON.parse(
  readFileSync(new URL('../entry/src/main/resources/en_US/element/string.json', import.meta.url), 'utf8')
);
const moduleJson = readFileSync(
  new URL('../entry/src/main/module.json5', import.meta.url),
  'utf8'
);
const bluetoothReason = stringValue(strings, 'permission_bluetooth_reason');
const internetReason = stringValue(strings, 'permission_internet_reason');
const wifiReason = stringValue(strings, 'permission_wifi_reason');
ok(
  'bluetooth reason tells purpose with period',
  isHuaweiPermissionReason(bluetoothReason) && bluetoothReason.includes('扫描') && bluetoothReason.includes('蓝牙')
);
ok('internet reason tells purpose with period', isHuaweiPermissionReason(internetReason));
ok('wifi reason tells purpose with period', isHuaweiPermissionReason(wifiReason));
ok(
  'ACCESS_BLUETOOTH declares reason and in-use scene',
  moduleJson.includes('"name": "ohos.permission.ACCESS_BLUETOOTH"') &&
    moduleJson.includes('$string:permission_bluetooth_reason') &&
    moduleJson.includes('"when": "inuse"')
);
ok(
  'privacy consent lists bluetooth purpose',
  stringValue(strings, 'privacy_dialog_body').includes('蓝牙权限用于扫描并展示周围蓝牙设备')
);
ok(
  'en_US bluetooth reason tells purpose',
  isHuaweiPermissionReason(stringValue(enStrings, 'permission_bluetooth_reason'))
);
function stringNames(doc) {
  return (doc.string || []).map((item) => item.name).sort();
}
const zhStrings = JSON.parse(
  readFileSync(new URL('../entry/src/main/resources/zh_CN/element/string.json', import.meta.url), 'utf8')
);
const enGenericStrings = JSON.parse(
  readFileSync(new URL('../entry/src/main/resources/en/element/string.json', import.meta.url), 'utf8')
);
ok(
  'en_US covers every base UI string',
  JSON.stringify(stringNames(enStrings)) === JSON.stringify(stringNames(strings))
);
ok(
  'en covers every base UI string',
  JSON.stringify(stringNames(enGenericStrings)) === JSON.stringify(stringNames(strings))
);
ok(
  'zh_CN covers every base UI string',
  JSON.stringify(stringNames(zhStrings)) === JSON.stringify(stringNames(strings))
);
ok(
  'en_US scan fallbacks are English',
  stringValue(enStrings, 'unknown_device') === 'Unknown device' &&
    stringValue(enStrings, 'unknown_ble_device') === 'Unknown Bluetooth device' &&
    stringValue(enStrings, 'adv_connectable') === 'Connectable' &&
    stringValue(enStrings, 'adv_broadcast_only') === 'Broadcast only' &&
    stringValue(enStrings, 'inventory_a11y_pick_ble') === '%1$s, Bluetooth'
);
ok(
  'en_US privacy dialog is fully English',
  stringValue(enStrings, 'privacy_dialog_title') === 'Privacy policy' &&
    stringValue(enStrings, 'privacy_dialog_agree') === 'Agree and continue' &&
    stringValue(enStrings, 'privacy_dialog_decline') === "Don't agree" &&
    stringValue(enStrings, 'btn_home_inventory') === 'Find nearby devices'
);
ok(
  'zh_CN bluetooth reason matches base purpose',
  stringValue(zhStrings, 'permission_bluetooth_reason') === bluetoothReason
);
ok(
  'bluetooth reason stays within two-line limit',
  [...bluetoothReason].length <= 36
);
const abilitySource = readFileSync(
  new URL('../entry/src/main/ets/entryability/EntryAbility.ets', import.meta.url),
  'utf8'
);
ok(
  'no custom dialog before system bluetooth prompt',
  inventorySource.includes('requestBluetoothPermission(') &&
    !inventorySource.includes('dialog_bluetooth_title') &&
    inventorySource.includes('dialog_bluetooth_denied_title')
);
ok(
  'permission deny uses wait-then-settings',
  inventorySource.includes('nextBluetoothPermissionStep') &&
    inventorySource.includes("step === 'wait'")
);
ok(
  'EntryAbility does not request permissions at launch',
  !abilitySource.includes('requestPermissionsFromUser') &&
    !abilitySource.includes('requestPermissionOnSetting')
);
ok(
  'bluetooth permission only asked on inventory scan',
  inventorySource.includes('ensureBluetoothPermission') &&
    inventorySource.includes('startInventoryScan')
);
const permAskAt = inventorySource.indexOf('ensureBluetoothPermission(context)');
const btEnabledAt = inventorySource.indexOf('BluetoothHelper.isEnabled()');
ok(
  'inventory asks bluetooth permission before adapter check',
  permAskAt >= 0 && btEnabledAt > permAskAt
);
ok(
  'mock scan still requests bluetooth permission',
  inventorySource.includes('const useMockBle = BleScanCoordinator.useMockScan()') &&
    inventorySource.includes('const btGranted = await this.ensureBluetoothPermission') &&
    permAskAt > inventorySource.indexOf('const useMockBle = BleScanCoordinator.useMockScan()')
);
const appearBlock = inventorySource.slice(
  inventorySource.indexOf('aboutToAppear()'),
  inventorySource.indexOf('aboutToDisappear()')
);
ok(
  'inventory does not auto-ask bluetooth on appear',
  appearBlock.includes('ScanUiLabels.load') &&
    !appearBlock.includes('startInventoryScan') &&
    !appearBlock.includes('ensureBluetoothPermission')
);
ok(
  'wifi-only toast only when bluetooth granted',
  inventorySource.includes('if (!enableLanScan && !useMockBle && enableBleScan)')
);

const purposeSource = readFileSync(
  new URL('../entry/src/main/ets/common/PermissionPurpose.ets', import.meta.url),
  'utf8'
);
ok(
  'reason helper matches mjs anti-patterns',
  purposeSource.includes('需要权限') &&
    purposeSource.includes('获取权限') &&
    purposeSource.includes('使用蓝牙。') &&
    purposeSource.includes('Used to')
);

const pickerSource = readFileSync(
  new URL('../entry/src/main/ets/components/InventoryDevicePickerSheet.ets', import.meta.url),
  'utf8'
);
const mdnsSource = readFileSync(
  new URL('../entry/src/main/ets/service/MdnsScanService.ets', import.meta.url),
  'utf8'
);
const coordinatorSource = readFileSync(
  new URL('../entry/src/main/ets/service/HomeInventoryCoordinator.ets', import.meta.url),
  'utf8'
);
ok('inventory loads scan labels', inventorySource.includes('ScanUiLabels.load('));
ok('picker a11y uses locale template', pickerSource.includes('ScanUiLabels.pickerA11y'));
ok('mdns unknown name uses locale label', mdnsSource.includes('ScanUiLabels.unknownDevice'));
ok(
  'coordinator unknown ble uses locale label',
  coordinatorSource.includes('ScanUiLabels.unknownBleDevice')
);

function stringLiterals(src) {
  const out = [];
  const re = /'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|`(?:\\.|[^`\\])*`/g;
  let m = re.exec(src);
  while (m) {
    out.push(m[0]);
    m = re.exec(src);
  }
  return out;
}

function listEts(relDir) {
  return readdirSync(new URL(`../${relDir}`, import.meta.url))
    .filter((name) => name.endsWith('.ets'))
    .map((name) => `${relDir}/${name}`);
}

const uiEts = [
  ...listEts('entry/src/main/ets/pages'),
  ...listEts('entry/src/main/ets/components'),
  'entry/src/main/ets/service/HomeInventoryCoordinator.ets',
  'entry/src/main/ets/common/BleAdvertParser.ets'
];
const cjkHits = [];
for (const rel of uiEts) {
  const src = readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8');
  const hits = stringLiterals(src).filter((item) => /[\u4e00-\u9fff]/.test(item));
  if (hits.length > 0) {
    cjkHits.push(`${rel}: ${hits.join(' | ')}`);
  }
}
ok('production UI ets has no hardcoded Chinese literals', cjkHits.length === 0);
if (cjkHits.length > 0) {
  console.error(cjkHits.join('\n'));
}

const privacyDialogSource = readFileSync(
  new URL('../entry/src/main/ets/components/PrivacyConsentDialog.ets', import.meta.url),
  'utf8'
);
ok(
  'privacy dialog body scrolls above pinned buttons',
  privacyDialogSource.includes('Scroll()') &&
    privacyDialogSource.includes('computePrivacyBodyScrollMaxHeightVp') &&
    privacyDialogSource.includes('constraintSize({ maxHeight: this.bodyScrollMaxHeightVp() })') &&
    privacyDialogSource.includes('.layoutWeight(1)') &&
    !privacyDialogSource.includes('.height(this.bodyScrollMaxHeightVp())') &&
    privacyDialogSource.includes('privacy_dialog_agree') &&
    privacyDialogSource.indexOf('Scroll()') < privacyDialogSource.indexOf('privacy_dialog_agree')
);
ok(
  'english privacy policy page exists',
  existsSync(new URL('../legal/privacy-en.html', import.meta.url))
);

const FONT_TITLE = 34;
const FONT_BODY = 17;
const TOUCH_TARGET_VP = 44;
function privacyDialogChromeHeightVp() {
  return 24 * 2 + FONT_TITLE + 16 * 3 + FONT_BODY + TOUCH_TARGET_VP;
}
function computePrivacyDialogMaxHeightVp(windowHeightVp) {
  const chrome = privacyDialogChromeHeightVp();
  if (windowHeightVp <= 0) {
    return chrome + 96;
  }
  return Math.max(chrome + 48, windowHeightVp - 32 * 2);
}
function computePrivacyBodyScrollMaxHeightVp(windowHeightVp) {
  if (windowHeightVp <= 0) {
    return 96;
  }
  const available = computePrivacyDialogMaxHeightVp(windowHeightVp) - privacyDialogChromeHeightVp();
  return Math.max(48, Math.min(420, available));
}
ok('privacy dialog tall window caps body scroll', computePrivacyBodyScrollMaxHeightVp(800) === 420);
ok(
  'privacy dialog landscape keeps buttons on screen',
  privacyDialogChromeHeightVp() + computePrivacyBodyScrollMaxHeightVp(360) + 64 <= 361
);

console.log('---');
console.log(failed === 0 ? 'All local layout checks passed.' : `${failed} check(s) failed.`);
process.exit(failed ? 1 : 0);
