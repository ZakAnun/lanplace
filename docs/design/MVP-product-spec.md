# 蓝域 BlueScopes — MVP 产品设计（v2）

**开发者：** 李铭淋（个人开发者）  
**联系：** linhenji@163.com  
**视觉基准：** [DESIGN-apple.md](./DESIGN-apple.md) + [lansuoji-ui-mapping.md](./lansuoji-ui-mapping.md)  
**HarmonyOS：** Stage / phone / SDK 26；在系统组件行为基础上套用 Apple 色板与排版节奏。

> **相对旧版规格的变化：** 首版 **仅一个首页**；**不做** GPS 场景、Place 数据库、多 Tab、账号、设备详情点击、配对管理。只做 **周围 BLE 扫描展示（只读列表）**。

---

## 1. MVP 目标

| 项 | 内容 |
|----|------|
| 用户价值 | 进入 App → 首页 Idle（蓝牙发现动效）→ 一键查看 **当前周围正在广播的蓝牙设备** |
| 交互 | 列表 **不可点击**（无详情页、无连接） |
| 数据 | **仅内存**；退出进程不保留；**不上传** |
| 账号 | **无** |
| 文案 | 首版按实现写占位；上架前再润色 |

---

## 2. 单页结构与状态机

仅 **`pages/Home.ets`**（替换现有 `Index.ets`）。

```text
┌─────────────────────────────────────┐
│  [Harmony 安全区 + Apple 留白]       │
│                                     │
│   Idle：引导 + 蓝牙发现动效（Canvas）  │
│   - 标题 / 副说明 / 主按钮           │
│   - 「查看周围蓝牙设备」              │
│                                     │
│   P0 隐私（首次启动）                 │
│   - 未同意则弹窗；不同意退出          │
│   - 同意并继续 → 可进入扫描流程       │
│                                     │
│   Scanning：扫描中                    │
│   - Loading + 停止 + 实时列表         │
│   - 30s 自动 stop 或用户停止          │
│                                     │
│   Results：结果（只读）               │
│   - hairline 卡片行；无 onClick       │
└─────────────────────────────────────┘
```

**P0 隐私：** 首次启动若未同意则展示弹窗；点主按钮时若仍未同意也会再次弹出。政策链由 **系统浏览器** 打开（见 §6）。

---

## 3. UI：Harmony + DESIGN-apple

| 规则 | 实现 |
|------|------|
| 主色 | `#0066cc`（Action Blue）按钮/链接 |
| 背景 | `#ffffff` / `#f5f5f7` 交替区块，**无装饰渐变**（与图标纯色底一致） |
| 字体 | HarmonyOS Sans；标题 600、正文 17fp、负 letterSpacing |
| 按钮 | `{rounded.pill}` 主按钮；按下 `scale(0.95)` |
| 列表 | `{rounded.lg}` + 1px `#e0e0e0`；**无卡片阴影** |
| 组件 | 优先 ArkUI `List` / `Column`；不引入第三方 UI 库 |

**Idle 动效（当前实现）：**  
- `BleDiscoveryRadar`：3D 粒子球 + 脉冲环（Canvas，`setInterval` 驱动）  
- Idle / Scanning 阶段展示；Results 无设备时不展示雷达（避免「仍在扫描」误解）  
- **无** 独立 Splash / Intro 页；系统启动窗后即进入 Home Idle

---

## 4. 权限：最小集 + 真机回退

### 4.1 首版声明（目标最小集）

| 权限 | 用途 | 申请时机 |
|------|------|----------|
| `ohos.permission.ACCESS_BLUETOOTH` | BLE 扫描、发现周围设备（API 10+ 统一蓝牙权限） | 用户点「查看周围蓝牙设备」前：应用说明 → 系统授权 |
| （不声明）`INTERNET` | 隐私政策由 **系统浏览器** 打开 | 本应用不持有网络权限 |

**首版不声明（除非真机扫描失败）：**

- `APPROXIMATELY_LOCATION` / `LOCATION` — 旧版/部分机型 BLE 可能要求；**MVP 先不申请**；真机 `startBLEScan` 失败且文档/错误码指向位置时再 **增权限并更新隐私政策**。
- `LOCATION_IN_BACKGROUND`、通讯录、存储、相机等 — **不申请**。

### 4.2 蓝牙权限说明（HarmonyOS NEXT）

- 以 **`ACCESS_BLUETOOTH`** 为主（含低功耗扫描能力，user_grant）。  
- **不** 为「完整列表」预申请已废弃的 `USE_BLUETOOTH` / `DISCOVER_BLUETOOTH`（除非目标 API 实测强制，再文档化追加）。  
- 若 SDK 26 扫描仍报错缺权限，按官方错误码 **最小追加**，同步改 `module.json5` 与隐私政策。

### 4.3 弹窗策略（精简）

| 步骤 | 行为 |
|------|------|
| 首次启动 | P0：隐私摘要 + 同意/不同意（不同意则退出） |
| 点主按钮 | 若未授权蓝牙：说明用途 → `requestPermissionsFromUser(ACCESS_BLUETOOTH)` |
| 打开隐私链接 | `startAbility(viewData)` → 系统浏览器；**无** 应用 INTERNET 权限 |

---

## 5. 蓝牙：可展示信息上限（协议 + 鸿蒙 API）

### 5.1 系统直接提供（`ble.ScanResult`）

| 字段 | 说明 | MVP 列表 |
|------|------|----------|
| `deviceId` | 设备地址（常为 **随机 MAC**） | 展示（可缩写） |
| `deviceName` | 扫描到的名称 | 展示，空则「未知设备」 |
| `rssi` | 信号强度 dBm | 展示 + 可选排序 |
| `connectable` | 是否可连接 | 展示标签 |
| `data` | 原始广播 `ArrayBuffer`（≤31 字节 AD 有效载荷） | 解析后展示摘要 |

**不能通过「仅扫描、不连接」可靠拿到：** 真实型号、已配对名、电量、厂商型号字符串（除非在广播里）、GATT 内部特征值。

### 5.2 自行解析 `data`（BLE AD 结构，首版尽量全展示）

按 Bluetooth Core Spec AD Type 解析（参考 OpenHarmony `BluetoothScan.ets` 示例）：

| 解析项 | AD Type | MVP 展示 |
|--------|---------|----------|
| 广播 Flags | 0x01 | 十六进制或简短说明 |
| 完整/短本地名 | 0x09 / 0x08 | 优先于空 `deviceName` |
| TX Power | 0x0A | dBm |
| 16/32/128-bit Service UUID | 0x02–0x07 等 | 列表或折叠一行 |
| Service Data | 0x16 等 | hex 摘要 |
| Manufacturer Specific | 0xFF | Company ID + hex 摘要 |

**列表行建议（只读，无点击）：**

1. 主行：`deviceName` 或解析名  
2. 副行：`deviceId` · RSSI · `可连接/仅广播`  
3. 可选第三行（caption）：UUID / Manufacturer / Flags 摘要  

**去重：** 以 `deviceId` 为键，RSSI 更新刷新行。

---

## 6. 联网与「第三方」

| 能力 | 是否使用 | 第三方 |
|------|----------|--------|
| 加载隐私政策 URL | 是（HTTPS，经系统浏览器） | **无**；静态页托管（如 GitHub Pages），非 SDK |
| 统计 / 广告 / 推送 | 否 | 无 |
| 地图 / 逆地理 | 否 | 无 |
| 账号后端 | 否 | 无 |

隐私政策须写明：**本应用不申请网络权限；政策页由系统浏览器打开；不通过第三方 SDK 收集个人信息。**

---

## 7. 隐私政策（MVP 与权限一致）

**开发者：** 李铭淋  
**邮箱：** linhenji@163.com  
**应用：** 蓝域（BlueScopes）

### 7.1 处理的信息

- **蓝牙扫描结果**（设备标识、名称、信号强度、广播解析数据）：仅在您点击扫描后于 **本机界面展示**，**不存储不上传**（进程结束即失）。  
- **隐私政策链接**：通过系统浏览器打开 HTTPS 页面；应用本身不申请 INTERNET。

### 7.2 设备权限（与 module.json5 一致）

| 隐私标签名 | 权限 | 用途 |
|------------|------|------|
| 设备发现和连接 | ACCESS_BLUETOOTH | 扫描并展示周围蓝牙设备 |

### 7.3 第三方 SDK

**无。**

### 7.4 用户权利

关闭权限可停止扫描；卸载即清除全部数据。

> 完整中英 HTML 待 MVP 权限定稿后写入 `docs/legal/`（与 AGC 一致）。

---

## 8. 非目标（MVP 不做）

- GPS / 50m Place / 本地 DB / 多 Tab / 设备详情 / 点击列表项  
- 配对、连接、GATT 读写  
- 账号、云同步  
- 后台扫描  

（后续版本可再引入「场景」能力，与当前 MVP 文档分离。）

---

## 9. 工程清单（实现时）

| 文件 | 说明 |
|------|------|
| `pages/Home.ets` | 唯一页面 + Idle / Scanning / Results |
| `ets/service/BleScanService.ets` | 扫描生命周期 |
| `ets/common/BleAdvertParser.ets` | AD 解析 |
| `ets/common/AppleTheme.ets` | 设计 token |
| `module.json5` | ACCESS_BLUETOOTH |
| `PrivacyConsentDialog.ets` | P0 |

---

## 10. 设计阶段仍待 MVP 后定稿

- 所有用户可见 **中文案**（标题、按钮、空态）  
- 隐私政策 **生效日期** 与 Pages 最终 URL  
- 真机确认是否 **追加位置权限**  
- 商店截图与简介  

---

## 修订

| 版本 | 日期 | 说明 |
|------|------|------|
| 2.0 | 2026-10-23 | 按 10 项需求收窄 MVP；李铭淋；单页扫描只读 |
