# 蓝域 BlueScopes MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付单页 HarmonyOS MVP：入场动效 → 隐私同意 → 蓝牙授权 → BLE 扫描 → 只读设备列表（含广播解析），DESIGN-apple 视觉，无 GPS/DB/账号。

**Architecture:** `Home.ets` 驱动 UI 状态机 S0–S4；`BleScanService` 封装扫描；`BleAdvertParser` 解析 AD；`PermissionHelper` + `PrivacyConsentHelper` 处理 P0/蓝牙授权；数据仅 `@State` 内存 Map。

**Tech Stack:** HarmonyOS Stage, ArkTS, ArkUI, `@kit.ConnectivityKit` BLE, `@kit.AbilityKit` 权限, Preferences, Hypium。

**Design spec:** `docs/design/MVP-product-spec.md`

## Global Constraints

- 包名 `com.lanplace.bluescopes`；中文名 **蓝域**；英文 **BlueScopes**；开发者 **李铭淋**；隐私邮箱 **linhenji@163.com**。
- 单页面 `pages/Home.ets`；**无** GPS、50m Place、多 Tab、列表项点击、配对/连接、持久化 DB、第三方 SDK。
- 权限首版：`ohos.permission.ACCESS_BLUETOOTH`；`ohos.permission.INTERNET` 仅用于打开隐私政策 URL（系统浏览器 `startAbility` action.viewData）。
- 扫描超时 **30s**；列表按 **RSSI 降序**；去重键 **deviceId**。
- UI：主色 `#0066cc`，背景 `#ffffff` / `#f5f5f7`，pill 按钮，列表无阴影。
- `compatibleSdkVersion`: `6.1.1(24)`，`modelVersion`: `26.0.0`，deviceTypes `phone`。

---

## File Map

| 路径 | 职责 |
|------|------|
| `entry/src/main/ets/common/Constants.ets` | 超时、Preferences 键、隐私 URL |
| `entry/src/main/ets/common/AppleTheme.ets` | 颜色/字号/圆角常量 |
| `entry/src/main/ets/common/BleAdvertParser.ets` | AD 解析 |
| `entry/src/main/ets/model/ScannedDevice.ets` | 列表行模型 |
| `entry/src/main/ets/service/BleScanService.ets` | start/stop/onFind |
| `entry/src/main/ets/common/PermissionHelper.ets` | 蓝牙权限 |
| `entry/src/main/ets/common/PrivacyConsentHelper.ets` | P0 Preferences |
| `entry/src/main/ets/components/PrivacyConsentDialog.ets` | 隐私弹窗 |
| `entry/src/main/ets/components/DeviceListItem.ets` | 只读行 UI |
| `entry/src/main/ets/pages/Home.ets` | 状态机 + 动效 |
| `entry/src/main/module.json5` | requestPermissions |
| `entry/src/main/resources/base/element/color.json` | Apple tokens |
| `entry/src/main/resources/base/element/string.json` | 文案、permission reason |
| `entry/src/test/BleAdvertParser.test.ets` | 解析单测 |
| `docs/legal/privacy-zh.html` | 隐私页（静态） |
| `entry/src/main/ets/entryability/EntryAbility.ets` | loadContent Home |

---

### Task 1: 主题常量与 color 资源

**Files:**
- Create: `entry/src/main/ets/common/Constants.ets`
- Create: `entry/src/main/ets/common/AppleTheme.ets`
- Modify: `entry/src/main/resources/base/element/color.json`

**Interfaces:**
- Produces: `SCAN_TIMEOUT_MS`, `PRIVACY_POLICY_URL`, `PRIVACY_ACCEPTED_KEY`, `SKIP_INTRO_KEY`
- Produces: `AppleTheme.PRIMARY`, `CANVAS`, `PARCHMENT`, `INK`, `INK_MUTED`, `HAIRLINE`, `RADIUS_PILL`, `RADIUS_LG`, `FONT_BODY`, `FONT_TITLE`

- [ ] **Step 1: Constants.ets**

```typescript
export const SCAN_TIMEOUT_MS: number = 30000;
export const PRIVACY_ACCEPTED_KEY: string = 'privacy_accepted_v1';
export const SKIP_INTRO_KEY: string = 'skip_intro_animation';
/** 替换为 GitHub Pages 实际上线地址 */
export const PRIVACY_POLICY_URL: string = 'https://zakanun.github.io/lanplace-bt/privacy-zh.html';
```

- [ ] **Step 2: AppleTheme.ets** — 导出上述 hex/fp 常量（与 MVP-product-spec §3 一致）

- [ ] **Step 3: color.json** 增加 `primary`, `canvas`, `parchment`, `ink`, `hairline` 资源色

- [ ] **Step 4: Commit** — `feat: add Apple theme constants and colors`

---

### Task 2: BleAdvertParser + 单测

**Files:**
- Create: `entry/src/main/ets/common/BleAdvertParser.ets`
- Create: `entry/src/main/ets/model/ScannedDevice.ets`
- Create: `entry/src/test/BleAdvertParser.test.ets`

**Interfaces:**
- Produces: `ParsedAdvert` — `{ flags?: number; localName?: string; txPower?: number; serviceUuids: string[]; manufacturerHex?: string; serviceDataHex?: string }`
- Produces: `parseAdvertData(data: ArrayBuffer): ParsedAdvert`
- Produces: `mergeScanResult(deviceId, deviceName, rssi, connectable, data): ScannedDevice`

- [ ] **Step 1: 写失败单测** — 构造含 0x09 Complete Local Name + 0xFF Manufacturer 的 Uint8Array，断言 `localName` 与 manufacturer 解析

```typescript
import { describe, it, expect } from '@ohos/hypium';
import { parseAdvertData } from '../main/ets/common/BleAdvertParser';

export default function bleAdvertParserTest() {
  describe('BleAdvertParser', () => {
    it('parses_complete_local_name', 0, () => {
      const name = 'Test';
      const ad: number[] = [name.length + 1, 0x09, ...Array.from(name).map(c => c.charCodeAt(0))];
      const buf = new Uint8Array(ad).buffer;
      const parsed = parseAdvertData(buf);
      expect(parsed.localName).assertEqual('Test');
    });
  });
}
```

- [ ] **Step 2: 运行单测 — FAIL**

- [ ] **Step 3: 实现 parseAdvertData** — 循环 `[len][type][payload]`；处理 0x01 Flags, 0x08/0x09 name, 0x0A tx, 0x02/0x03/0x04/0x06/0x07 UUID 列表, 0xFF manufacturer

- [ ] **Step 4: ScannedDevice.ets** — 字段：`deviceId`, `displayName`, `rssi`, `connectable`, `detailLine`, `advertSummary`

- [ ] **Step 5: mergeScanResult** — `displayName = deviceName || parsed.localName || '未知设备'`；`detailLine` 拼接 id/rssi/connectable；`advertSummary` UUID/Mfg 摘要

- [ ] **Step 6: 单测 PASS + Commit** — `feat: ble advert parser with tests`

---

### Task 3: BleScanService

**Files:**
- Create: `entry/src/main/ets/service/BleScanService.ets`

**Interfaces:**
- Consumes: `mergeScanResult`, `SCAN_TIMEOUT_MS`
- Produces: `BleScanService.start(onUpdate: (devices: ScannedDevice[]) => void): void`
- Produces: `BleScanService.stop(): void`
- Produces: `BleScanService.isScanning(): boolean`

- [ ] **Step 1: 实现** — `import { ble } from '@kit.ConnectivityKit'`（若编译失败改 `@ohos.bluetooth.ble` 与官方 SDK26 文档一致）

```typescript
ble.on('BLEDeviceFind', (results: ble.ScanResult[]) => { /* merge to Map by deviceId, throttle 400ms */ });
ble.startBLEScan([], { interval: 0, dutyMode: ble.ScanDuty.SCAN_MODE_LOW_LATENCY });
setTimeout(() => stop(), SCAN_TIMEOUT_MS);
```

- [ ] **Step 2: stop** — `ble.off('BLEDeviceFind')`, `ble.stopBLEScan()`, 清 timer

- [ ] **Step 3: 错误处理** — 蓝牙未开启时 throw 可识别错误，供 Home 显示 Toast

- [ ] **Step 4: Commit** — `feat: ble scan service`

---

### Task 4: 权限与隐私 Preferences

**Files:**
- Create: `entry/src/main/ets/common/PermissionHelper.ets`
- Create: `entry/src/main/ets/common/PrivacyConsentHelper.ets`

**Interfaces:**
- Produces: `hasBluetoothPermission(context): Promise<boolean>`
- Produces: `requestBluetoothPermission(context): Promise<boolean>`
- Produces: `isPrivacyAccepted(context): Promise<boolean>`
- Produces: `setPrivacyAccepted(context, accepted: boolean): Promise<void>`
- Produces: `shouldSkipIntro(context): Promise<boolean>` / `setSkipIntro(context): Promise<void>`

- [ ] **Step 1: PermissionHelper** — `abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, ['ohos.permission.ACCESS_BLUETOOTH'])`

- [ ] **Step 2: PrivacyConsentHelper** — `preferences.getPreferences(context, 'bluescopes_prefs')`

- [ ] **Step 3: Commit** — `feat: permission and privacy helpers`

---

### Task 5: module.json5 与 string 资源

**Files:**
- Modify: `entry/src/main/module.json5`
- Modify: `entry/src/main/resources/base/element/string.json`

- [ ] **Step 1: requestPermissions**

```json5
"requestPermissions": [
  {
    "name": "ohos.permission.ACCESS_BLUETOOTH",
    "reason": "$string:permission_bluetooth_reason",
    "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
  },
  {
    "name": "ohos.permission.INTERNET",
    "reason": "$string:permission_internet_reason",
    "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
  }
]
```

- [ ] **Step 2: strings** — `permission_bluetooth_reason`: 用于扫描并展示周围蓝牙设备；`permission_internet_reason`: 用于打开隐私政策网页；占位 UI 文案

- [ ] **Step 3: Commit** — `feat: declare bluetooth and internet permissions`

---

### Task 6: PrivacyConsentDialog + 打开隐私 URL

**Files:**
- Create: `entry/src/main/ets/components/PrivacyConsentDialog.ets`

**Interfaces:**
- Consumes: `PRIVACY_POLICY_URL`, `setPrivacyAccepted`
- Produces: `@CustomDialog` 组件：`onAgree()`, `onDecline()`, `onOpenPolicy()`

- [ ] **Step 1: 弹窗 UI** — canvas 背景、摘要 Text、`隐私政策` text-link、`同意并继续` pill、`不同意` secondary

- [ ] **Step 2: onOpenPolicy** — `import { common } from '@kit.AbilityKit'` + `context.startAbility({ action: 'ohos.want.action.viewData', entities: ['entity.system.browsable'], uri: PRIVACY_POLICY_URL })`

- [ ] **Step 3: onDecline** — `context.terminateSelf()`（MVP-product-spec §4.3）

- [ ] **Step 4: Commit** — `feat: privacy consent dialog`

---

### Task 7: DeviceListItem（只读）

**Files:**
- Create: `entry/src/main/ets/components/DeviceListItem.ets`

**Interfaces:**
- Consumes: `ScannedDevice`, `AppleTheme`
- Produces: `@Component struct DeviceListItem` — **无 onClick**

- [ ] **Step 1:** 白底卡片 `border 1px hairline`, `borderRadius 18`, padding 24；三行 Text

- [ ] **Step 2: Commit** — `feat: read-only device list item`

---

### Task 8: Home.ets 状态机与动效

**Files:**
- Create: `entry/src/main/ets/pages/Home.ets`
- Modify: `entry/src/main/resources/base/profile/main_pages.json`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Delete or keep unused: `entry/src/main/ets/pages/Index.ets`（从 main_pages 移除）

**Interfaces:**
- Consumes: 全部前述模块

- [ ] **Step 1: enum UiPhase { Intro, Idle, Scanning, Results }**

- [ ] **Step 2: S0 Intro** — `animateTo` 背景色 + 2–3 个 Circle scale/opacity；右上角「跳过」→ `setSkipIntro` → Idle

- [ ] **Step 3: S1 Idle** — 标题占位 + `查看周围蓝牙设备` Button.onClick → 检查 privacy → dialog → bluetooth rationale AlertDialog → request → start scan

- [ ] **Step 4: S3 Scanning** — LoadingProgress + `停止扫描` Button

- [ ] **Step 5: S4 List** — `List({ space: 12 }) { ForEach(devices sorted by rssi) { DeviceListItem } }` **禁止** `.onClick` on items

- [ ] **Step 6: main_pages** — `["pages/Home"]`；EntryAbility `loadContent('pages/Home')`

- [ ] **Step 7: aboutToDisappear** — `BleScanService.stop()`

- [ ] **Step 8: Commit** — `feat: home page with intro animation and ble list`

---

### Task 9: 隐私静态页与真机验证清单

**Files:**
- Create: `docs/legal/privacy-zh.html`（内容来自 `docs/design/privacy-policy-mvp-zh.md`）

- [ ] **Step 1:** HTML 静态页，含李铭淋、linhenji@163.com、ACCESS_BLUETOOTH、INTERNET 说明、无第三方 SDK

- [ ] **Step 2: 真机 UAT**
  - 首次启动 P0 → 同意 → 动效 → 扫描 → 列表更新
  - 拒绝蓝牙 → 提示去设置
  - 列表项点击无反应
  - 杀进程再开列表为空（内存不持久化）
  - 若 `startBLEScan` 错误码提示缺位置：记录并走「Task 10 回退」

- [ ] **Step 3: Commit** — `docs: privacy html and mvp uat notes`

---

### Task 10（条件）: 真机需位置权限时

**Files:**
- Modify: `entry/src/main/module.json5`
- Modify: `docs/legal/privacy-zh.html`
- Modify: `PermissionHelper.ets`

- [ ] **Step 1:** 仅当 UAT 失败且官方文档要求时，增加 `ohos.permission.APPROXIMATELY_LOCATION` + reason + 政策段落「用于系统要求的蓝牙扫描，不用于定位轨迹」

- [ ] **Step 2: Commit** — `fix: add approximate location for ble scan on device`

---

## Spec Self-Review

| MVP 需求 | Task |
|----------|------|
| 单页 Home | 8 |
| 动效 + 跳过 | 8 |
| 只读列表 | 7, 8 |
| BLE 最大字段 | 2, 3 |
| P0 + 蓝牙授权 | 4, 5, 6, 8 |
| DESIGN-apple | 1, 7, 8 |
| 无 GPS/DB | 全局约束 |
| 隐私政策 | 6, 9 |
| INTERNET 仅政策 | 5, 6 |
| 开发者李铭淋 | 9 HTML |

**Placeholder scan:** `PRIVACY_POLICY_URL` 需在 Pages 上线后替换为最终 URL（Step 1 已给占位域名模式）。

---

## Execution Handoff

Plan complete and saved to:

- `docs/design/2026-10-23-mvp-implementation-plan.md`（仓库内，可提交）
- `docs/superpowers/plans/2026-10-23-bluescopes-mvp.md`（Superpowers 本地副本，与上同内容）

**Two execution options:**

1. **Subagent-Driven (recommended)** — 每 Task 一个子 agent，任务间 review  
2. **Inline Execution** — 当前会话按 Task 顺序实现，检查点批处理  

请选择 **1** 或 **2**。
