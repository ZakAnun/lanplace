# 蓝牙场景设备清单 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付可上架的 HarmonyOS 应用：按当前 GPS 位置自动匹配/创建 50m 场景（Place），同步已配对蓝牙设备并支持 BLE 扫描，设备与场景本地持久化；首页仅展示当前场景，「全部」展示跨场景历史。

**Architecture:** UI（3 Tab）→ `DeviceRepository` 编排 → `PlaceService`（GPS + 50m 匹配）+ `BluetoothConnectionService` + `BleScanService` → RelationalStore（`places` / `devices`）。无后端、无手动场景配置。

**Tech Stack:** HarmonyOS Stage 模型、ArkTS、ArkUI、RelationalStore、`@ohos.bluetooth.connection` / `@ohos.bluetooth.ble`、Location Kit、Hypium 单测。

## Global Constraints

- 单模块 `entry`，设备类型 `phone`；`compatibleSdkVersion`: `6.1.1(24)`，`modelVersion`: `26.0.0`。
- 场景半径固定 `PLACE_RADIUS_METERS = 50`，用户不可配置。
- 不实现：云同步、账号、地图 UI、系统配对/解绑、后台扫描、手动画围栏。
- 数据仅本机存储；上架前将 `bundleName` 从 `com.example.myapplication` 改为正式包名并完成 Release 签名。
- 权限：蓝牙 + 位置（定场景与 BLE 扫描）；扫描与 GPS 仅在用户可见流程中触发，首版不做后台定位。

---

## File Map

| 路径 | 职责 |
|------|------|
| `entry/src/main/module.json5` | 权限、`pages` |
| `entry/src/main/resources/base/profile/main_pages.json` | 页面路由 |
| `entry/src/main/resources/base/element/string.json` | 文案、权限 reason |
| `entry/src/main/ets/common/Constants.ets` | 半径、扫描超时等 |
| `entry/src/main/ets/common/GeoUtil.ets` | Haversine 距离（米） |
| `entry/src/main/ets/data/DatabaseHelper.ets` | 建表、升级 |
| `entry/src/main/ets/data/PlaceDao.ets` | Place CRUD |
| `entry/src/main/ets/data/DeviceDao.ets` | Device CRUD |
| `entry/src/main/ets/model/Place.ets` / `DeviceItem.ets` | 领域模型 |
| `entry/src/main/ets/service/PlaceService.ets` | `resolveCurrentPlace()` |
| `entry/src/main/ets/service/BluetoothConnectionService.ets` | 配对列表 |
| `entry/src/main/ets/service/BleScanService.ets` | 扫描生命周期 |
| `entry/src/main/ets/repository/DeviceRepository.ets` | 同步、扫描写入、查询 |
| `entry/src/main/ets/common/PermissionHelper.ets` | 权限请求 |
| `entry/src/main/ets/pages/Main.ets` | Tabs 容器 |
| `entry/src/main/ets/pages/HerePage.ets` | 当前场景 |
| `entry/src/main/ets/pages/AllDevicesPage.ets` | 全部设备 |
| `entry/src/main/ets/pages/SettingsPage.ets` | 我的 |
| `entry/src/main/ets/pages/DeviceDetailPage.ets` | 详情与备注 |
| `entry/src/main/ets/entryability/EntryAbility.ets` | `loadContent('pages/Main')` |
| `entry/src/test/GeoUtil.test.ets` | 距离计算单测 |
| `entry/src/test/PlaceMatch.test.ets` | Place 匹配逻辑单测 |

---

### Task 1: 常量、距离工具与单测

**Files:**
- Create: `entry/src/main/ets/common/Constants.ets`
- Create: `entry/src/main/ets/common/GeoUtil.ets`
- Create: `entry/src/test/GeoUtil.test.ets`

**Interfaces:**
- Produces: `PLACE_RADIUS_METERS`, `SCAN_TIMEOUT_MS`, `distanceMeters(lat1, lng1, lat2, lng2): number`

- [ ] **Step 1: Write failing test**

```typescript
// entry/src/test/GeoUtil.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { distanceMeters } from '../main/ets/common/GeoUtil';

export default function geoUtilTest() {
  describe('GeoUtil', () => {
    it('distanceMeters_samePoint_isZero', 0, () => {
      expect(distanceMeters(31.23, 121.47, 31.23, 121.47)).assertEqual(0);
    });
    it('distanceMeters_within50m', 0, () => {
      const d = distanceMeters(31.23, 121.47, 31.2304, 121.47);
      expect(d < 50).assertTrue();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: DevEco / `hvigorw test` 或 IDE 运行 `GeoUtil.test`  
Expected: FAIL — module `GeoUtil` not found

- [ ] **Step 3: Implement**

```typescript
// entry/src/main/ets/common/Constants.ets
export const PLACE_RADIUS_METERS: number = 50;
export const SCAN_TIMEOUT_MS: number = 30000;
export const DB_NAME: string = 'BluetoothPlace.db';
```

```typescript
// entry/src/main/ets/common/GeoUtil.ets
const EARTH_RADIUS_M = 6371000;

export function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const toRad = (d: number) => d * Math.PI / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(a)));
}
```

- [ ] **Step 4: Run test — PASS**

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/common/Constants.ets entry/src/main/ets/common/GeoUtil.ets entry/src/test/GeoUtil.test.ets
git commit -m "feat: add geo constants and distance helper"
```

---

### Task 2: RelationalStore 与 DAO

**Files:**
- Create: `entry/src/main/ets/model/Place.ets`, `DeviceItem.ets`
- Create: `entry/src/main/ets/data/DatabaseHelper.ets`
- Create: `entry/src/main/ets/data/PlaceDao.ets`, `DeviceDao.ets`

**Interfaces:**
- Produces: `DatabaseHelper.getStore()`, `PlaceDao.insert/update/queryAll/findNearestWithinRadius`, `DeviceDao.upsertBySystemId/queryByPlaceId/queryAllWithPlaceTitle`

- [ ] **Step 1: Define models**

```typescript
// Place.ets
export interface Place {
  id: number;
  centerLat: number;
  centerLng: number;
  title: string;
  createdAt: number;
  lastActiveAt: number;
}

// DeviceItem.ets
export type DeviceSource = 'paired' | 'nearby' | 'both';

export interface DeviceItem {
  id: number;
  systemDeviceId: string;
  displayName: string;
  systemName: string;
  source: DeviceSource;
  placeId: number;
  firstSeenAt: number;
  lastSeenAt: number;
  lastRssi?: number;
}
```

- [ ] **Step 2: DatabaseHelper 建表 SQL**

```sql
CREATE TABLE IF NOT EXISTS places (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  center_lat REAL NOT NULL,
  center_lng REAL NOT NULL,
  title TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_active_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS devices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  system_device_id TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  system_name TEXT NOT NULL,
  source TEXT NOT NULL,
  place_id INTEGER NOT NULL,
  first_seen_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  last_rssi INTEGER,
  FOREIGN KEY (place_id) REFERENCES places(id)
);
```

- [ ] **Step 3: PlaceDao — `findPlacesWithinRadius(lat, lng, radiusM)` 返回距离 ≤ radius 的 Place 列表**

- [ ] **Step 4: DeviceDao — upsert 时合并 `source`（paired + nearby → both）**

- [ ] **Step 5: 真机/模拟器验证** — EntryAbility 临时调用 init DB，hilog 打印 0 条

- [ ] **Step 6: Commit** — `feat: add local database for places and devices`

---

### Task 3: PlaceService（当前场景 A）

**Files:**
- Create: `entry/src/main/ets/service/PlaceService.ets`
- Create: `entry/src/test/PlaceMatch.test.ets`（纯函数：从候选 Place 中选 current）

**Interfaces:**
- Consumes: `PlaceDao`, `GeoUtil`, `Constants.PLACE_RADIUS_METERS`
- Produces: `PlaceService.resolveCurrentPlace(lat, lng): Promise<Place>` — 有则取 `last_active_at` 最大；无则 `insert` 新 Place，title 默认 `'当前位置'`（逆地理 Task 8 再接）

- [ ] **Step 1: 抽取 `pickCurrentPlace(candidates: Place[]): Place | null` 单测**

- [ ] **Step 2: 实现 resolveCurrentPlace 并更新 lastActiveAt**

- [ ] **Step 3: Commit** — `feat: resolve GPS place within 50m`

---

### Task 4: 蓝牙配对同步服务

**Files:**
- Create: `entry/src/main/ets/service/BluetoothConnectionService.ets`

**Interfaces:**
- Produces: `getPairedDevices(): Promise<Array<{ deviceId: string; name: string; connected?: boolean }>>`

- [ ] **Step 1: 检查蓝牙开关，关闭时 reject 可识别错误码**

- [ ] **Step 2: 使用 connection API 读取配对设备列表（按官方 SDK 26 文档方法名实现）**

- [ ] **Step 3: Commit** — `feat: bluetooth paired device reader`

---

### Task 5: BLE 扫描服务

**Files:**
- Create: `entry/src/main/ets/service/BleScanService.ets`

**Interfaces:**
- Produces: `startScan(onResult: (items: ScanResult[]) => void): void`, `stopScan(): void`
- `ScanResult`: `{ deviceId, name, rssi, serviceUuids? }`

- [ ] **Step 1: 注册 BLEDeviceFind，节流 400ms 回调**

- [ ] **Step 2: start 时设 SCAN_TIMEOUT_MS 自动 stopScan**

- [ ] **Step 3: onDestroy / 页面 aboutToDisappear 必须 stopScan**

- [ ] **Step 4: Commit** — `feat: ble scan service with timeout`

---

### Task 6: DeviceRepository

**Files:**
- Create: `entry/src/main/ets/repository/DeviceRepository.ets`

**Interfaces:**
- Consumes: PlaceService, BluetoothConnectionService, BleScanService, DAOs
- Produces:
  - `refreshCurrentPlaceAndSync(): Promise<Place>`
  - `getDevicesForPlace(placeId: number): Promise<DeviceItem[]>`
  - `getAllDevices(): Promise<(DeviceItem & { placeTitle: string })[]>`
  - `applyScanResults(placeId: number, results: ScanResult[]): Promise<void>`
  - `updateDisplayName(deviceId: number, name: string): Promise<void>`
  - `clearAllLocalData(): Promise<void>`

- [ ] **Step 1: syncPaired — 对每条配对 upsert 到 current placeId，source 含 paired**

- [ ] **Step 2: applyScanResults — nearby，合并已存在记录的 source**

- [ ] **Step 3: Commit** — `feat: device repository orchestration`

---

### Task 7: 权限与 module.json5

**Files:**
- Modify: `entry/src/main/module.json5`
- Create: `entry/src/main/ets/common/PermissionHelper.ets`
- Modify: `entry/src/main/resources/base/element/string.json`

**Interfaces:**
- Produces: `ensureBluetoothPermissions()`, `ensureLocationPermissions()`

- [ ] **Step 1: 声明 `ohos.permission.ACCESS_BLUETOOTH`，及 BLE 扫描所需的 MANAGE/LOCATION 类权限（以 SDK 文档为准）**

- [ ] **Step 2: HerePage 进入时 request 位置；点「扫描」前确认蓝牙+位置**

- [ ] **Step 3: Commit** — `feat: declare and request bluetooth location permissions`

---

### Task 8: UI — Main + Here + All + Settings + Detail

**Files:**
- Create: `entry/src/main/ets/pages/Main.ets`, `HerePage.ets`, `AllDevicesPage.ets`, `SettingsPage.ets`, `DeviceDetailPage.ets`
- Modify: `entry/src/main/resources/base/profile/main_pages.json`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`

**Interfaces:**
- Consumes: `DeviceRepository`, `PermissionHelper`

- [ ] **Step 1: main_pages.json 注册全部页面；EntryAbility loadContent `pages/Main`**

- [ ] **Step 2: Main — Tabs：此处 | 全部 | 我的**

- [ ] **Step 3: HerePage — 显示 place.title、说明「约 50 米范围」、分区「我的设备」「附近发现」、扫描按钮、下拉 refreshCurrentPlaceAndSync**

- [ ] **Step 4: AllDevicesPage — 列表含 placeTitle、跳转 Detail**

- [ ] **Step 5: DeviceDetailPage — 备注编辑、来源、RSSI、时间**

- [ ] **Step 6: SettingsPage — 权限说明、清除本地数据（调用 clearAllLocalData）、隐私政策 URL 占位、版本**

- [ ] **Step 7: 可选逆地理：PlaceService 新建 Place 时调用 geocoder 更新 title**

- [ ] **Step 8: 删除或保留 Index.ets 仅作跳转废弃（从 main_pages 移除 Index）**

- [ ] **Step 9: Commit** — `feat: main UI tabs and device pages`

---

### Task 9: 上架准备与自检

**Files:**
- Modify: `AppScope/app.json5`（label、正式 bundleName 与 AGC 一致）
- 隐私政策 URL（Settings 中链接）

- [ ] **Step 1: Release 编译，确认无 debug 模块**

- [ ] **Step 2: 手工 UAT 清单**
  - 同地点：同步 + 扫描 + 杀进程重启数据仍在
  - 拒权、关蓝牙：空态与引导
  - 清除数据后 DB 空

- [ ] **Step 3: 准备 AppGallery 隐私标签文案（位置、蓝牙、本地存储、不上传）**

- [ ] **Step 4: Commit** — `chore: release prep and app metadata`

---

## Spec Self-Review (Plan vs Spec)

| 需求 | Task |
|------|------|
| GPS 50m 自动 Place | 1, 3 |
| 首页仅当前场景 A | 7 HerePage |
| 全部跨场景 | 7 AllDevicesPage |
| 配对 + 扫描全功能 | 4, 5, 6 |
| 本地持久化 | 2, 6 |
| 无手动场景 | 无 Space CRUD UI |
| 权限与隐私 | 7, 9 |
| 备注 | 6, 7 Detail |

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-10-23-bluetooth-place-devices.md`.
