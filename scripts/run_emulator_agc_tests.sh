#!/usr/bin/env bash
# 在已 online 的 HarmonyOS 模拟器上跑 AGC 审核场景仪器化测试（需先编译 default + ohosTest HAP）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HDC="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
HVIGOR="${HVIGOR:-/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw}"
export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}"
BUNDLE='com.lanplace.bluescopes'
TEST_MODULE='entry_test'
TEST_RUNNER='OpenHarmonyTestRunner'
TIMEOUT_MS="${TEST_TIMEOUT_MS:-180000}"

echo "==> 检查设备"
if ! "$HDC" list targets 2>/dev/null | grep -qE '127\.0\.0\.1|emulator'; then
  echo "错误: 未检测到 online 模拟器/设备。请先在 DevEco 启动模拟器。" >&2
  exit 2
fi

BUILD="${BUILD_HAP:-0}"
if [[ "${1:-}" == "--build" ]]; then
  BUILD=1
fi

if [[ "$BUILD" == "1" ]]; then
  echo "==> 编译 entry default + ohosTest（debug）"
  cd "$ROOT"
  if [[ -z "${DEVECO_SDK_HOME:-}" ]]; then
    echo "提示: 若 CLI 编译失败，请在 DevEco 中 Build 生成 HAP，或在本机配置 DEVECO_SDK_HOME 后重试。" >&2
  fi
  "$HVIGOR" -p product=default -p buildMode=debug assembleHap -p module=entry@default -p module=entry@ohosTest
fi

DEFAULT_HAP="$ROOT/entry/build/default/outputs/default/entry-default-signed.hap"
TEST_HAP="$ROOT/entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap"

for f in "$DEFAULT_HAP" "$TEST_HAP"; do
  if [[ ! -f "$f" ]]; then
    echo "缺少 HAP: $f" >&2
    echo "请在 DevEco 中 Build 或使用: $0 --build" >&2
    exit 3
  fi
done

echo "==> 安装主包与测试包"
"$HDC" install -r "$DEFAULT_HAP"
"$HDC" install -r "$TEST_HAP"

echo "==> 运行仪器化测试（AGC 审核路径 + 横屏布局预算）"
"$HDC" shell aa test \
  -b "$BUNDLE" \
  -m "$TEST_MODULE" \
  -s unittest "$TEST_RUNNER" \
  -s timeout "$TIMEOUT_MS"

echo "==> 本地布局预算（无模拟器）"
if command -v node >/dev/null 2>&1; then
  node "$ROOT/scripts/verify_radar_layout_local.mjs"
fi

echo "==> 完成"
