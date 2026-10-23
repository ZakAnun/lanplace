# 蓝域 BlueScopes UI：DESIGN-apple 映射（HarmonyOS ArkUI）

**基准文档：** [DESIGN-apple.md](./DESIGN-apple.md)  
**产品规格（本地）：** `docs/superpowers/specs/2026-10-23-lansuoji-design.md`  
**原则：** 摄影/产品让位 → 本应用为 **设备清单**，主视觉是 **清晰列表 + 大标题 + 单一 Action Blue**；不用装饰渐变、卡片/按钮不加阴影（产品图若有例外再议）。

---

## 1. 品牌（与工程配置一致）

| 项 | 值 |
|----|-----|
| 中文名 | 蓝域 |
| 英文名 | BlueScopes（展示不用 `-`，强调 place scopes） |
| 包名 | com.lanplace.bluescopes |
| 仓库 / 目录 | **lanplace**（GitHub: `ZakAnun/lanplace`） |
| Logo | 纯色 Action Blue 底 + 白色 **Z** 主形（可含蓝牙/定位点缀） |

---

## 2. 颜色 → `entry/src/main/resources/base/element/color.json`

| Apple Token | Hex | 蓝域用途 |
|-------------|-----|------------|
| primary | #0066cc | 主按钮、链接、扫描 CTA、Tab 选中 |
| primary-focus | #0071e3 | 焦点环（若有） |
| primary-on-dark | #2997ff | 深色区块内链接 |
| ink | #1d1d1f | 主标题、列表主文案 |
| ink-muted-48 | #7a7a7a | 副文案、RSSI 说明 |
| canvas | #ffffff | 默认页背景 |
| canvas-parchment | #f5f5f7 | 「此处」交替区块、设置页底 |
| surface-tile-1 | #272729 | 可选：扫描中状态条 / 深色 Hero |
| hairline | #e0e0e0 | 列表分割、utility card 边框 |
| on-primary | #ffffff | 主按钮文字 |

**深色模式：** 首版可跟系统；dark/element/color.json 用 parchment ↔ tile 反转，primary 仍 #0066cc。

---

## 3. 字体（HarmonyOS 替代 SF Pro）

| Apple | HarmonyOS 建议 |
|-------|------------------|
| SF Pro Display 600 大标题 | `HarmonyOS Sans` / 系统默认，`fontWeight(FontWeight.Medium)` + `fontSize` 34–40vp |
| SF Pro Text 17 body | 17fp，`FontWeight.Regular`，`lineHeight` ≈ 1.47 |
| 负字距 headline | `letterSpacing` 约 -0.5vp ~ -1vp（大标题） |

定义 `@Styles` / 主题常量文件：`entry/src/main/ets/common/AppleTheme.ets`（token 名与 DESIGN-apple 对齐）。

---

## 4. 圆角与间距

| Token | 值 | 组件 |
|-------|-----|------|
| rounded.pill | 9999 | 「开始扫描」「同意并继续」 |
| rounded.lg | 18 | 设备卡片（store-utility-card） |
| rounded.sm | 8 | 次要按钮 |
| spacing.lg | 24 | 卡片内边距 |
| spacing.section | 80 | 首屏 Hero 上下（手机可降为 48） |

---

## 5. 页面 ↔ Apple 组件（MVP：仅 Home）

| 区域 / 状态 | 布局模式 |
|-------------|----------|
| **S0 入场动效** | 全屏 tile-dark ↔ canvas-parchment 淡入；中心 Logo/波纹；无渐变 chrome |
| **S1 引导** | display-lg + caption；`button-primary`「查看周围蓝牙设备」 |
| **S4 设备列表** | `store-utility-card` 或 List + hairline；**无 onClick** |
| **P0 隐私** | canvas 弹窗 + 链到隐私 URL（联网） |
| ~~多 Tab / Place / 详情~~ | **MVP 不做**（见 [MVP-product-spec.md](./MVP-product-spec.md)） |

---

## 6. 交互

- 按钮按下：`scale(0.95)`（`animation` + `Gesture` 或 `.stateStyles`）。
- **禁止：** 卡片阴影、背景装饰渐变（**含 App 内 chrome**；与当前图标渐变底冲突，见下）。

---

## 7. Logo 与 Apple 规范对齐（待确认后执行）

| 现状 | Apple 要求 | 建议 |
|------|------------|------|
| 图标 background 为蓝色渐变 | UI chrome 无装饰渐变 | 改为 **纯色 canvas 或 primary 平铺** + 前景符号 |
| 前景：蓝牙+定位白符号 | 单一 accent、简洁 | 保留符号，配色改为 **#0066cc 底 + 白标** 或 **白底 + #0066cc 标** |

确认名称/Logo 后，再出一版分层 icon 替换 `AppScope/.../background.png` & `foreground.png`。

---

## 8. 实施顺序（UI）

1. `color.json` + `AppleTheme.ets`  
2. `Main.ets` Tab 样式  
3. HerePage / AllDevices / Settings 按映射重构  
4. PrivacyConsentDialog / Permission 说明弹窗  
5. 图标 v2（去渐变）
