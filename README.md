# lanplace

HarmonyOS 单页应用：**周围 BLE 广播设备只读扫描与展示**（无连接、无持久化、无后端）。

## 技术栈

| 项 | 说明 |
|----|------|
| 运行时 | HarmonyOS Stage 模型，phone |
| SDK | target `26.0.0`，compatible `6.1.1(24)` |
| 语言 / UI | ArkTS，ArkUI 声明式 |
| 蓝牙 | `@kit.ConnectivityKit` — `startBLEScan` / `BLEDeviceFind` |
| 权限 | `ohos.permission.ACCESS_BLUETOOTH`（`inuse`） |
| 本地状态 | Preferences（隐私同意标记） |
| 测试 | Hypium（`BleAdvertParser` 单元测试） |

**包名：** `com.lanplace.bluescopes`

## 工程结构

```text
entry/src/main/ets/
├── pages/Home.ets              # Idle / Scanning / Results 状态机
├── service/BleScanService.ets  # 扫描生命周期、30s 超时、去重与 RSSI 排序
├── common/BleAdvertParser.ets  # BLE AD 解析（名称、UUID、TX Power、Manufacturer 等）
├── common/PermissionHelper.ets
├── common/PrivacyConsentHelper.ets
├── common/BluetoothHelper.ets
└── components/                 # 列表项、隐私弹窗、Canvas 发现动效
```

## 能力说明

- **扫描：** 低延迟 duty，结果按 `deviceId` 去重，RSSI 降序；节流刷新 UI；进后台停止扫描。
- **解析：** 16 / 32 / 128-bit Service UUID、本地名（UTF-8）、有符号 TX Power、Flags、Manufacturer / Service Data 摘要。
- **交互：** 隐私同意后申请蓝牙权限；列表只读；系统浏览器打开合规文档（`docs/legal/`，GitHub Pages 发布）。

## 构建

使用 DevEco Studio 打开工程，连接设备或模拟器，执行 **Build HAP** / Run。签名与 `compatibleSdkVersion` 按本地环境配置。
