#!/usr/bin/env bash
# Sync Flutter module HAR artifacts into ./har for HarmonyOS entry module.
# Requires OHOS-capable Flutter on PATH (OpenHarmony-SIG flutter_flutter), not stock Google Flutter.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_DIR="$ROOT/flutter_module"
HAR_DIR="$ROOT/har"
MODE="${1:-debug}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not on PATH. Use HarmonyOS Flutter SDK (flutter_flutter)." >&2
  exit 1
fi

if ! flutter build har -h 2>&1 | grep -q 'har'; then
  echo "error: this flutter CLI has no 'build har'. Install OpenHarmony Flutter SDK." >&2
  exit 1
fi

cd "$MODULE_DIR"
if [[ "$MODE" == "release" ]]; then
  flutter build har --release
  SRC="$MODULE_DIR/build/ohos/har/release"
else
  flutter build har
  SRC="$MODULE_DIR/build/ohos/har/debug"
fi

if [[ ! -d "$SRC" ]]; then
  echo "error: expected HAR output at $SRC" >&2
  exit 1
fi

mkdir -p "$HAR_DIR"
cp -f "$SRC"/*.har "$HAR_DIR/"
echo "Copied HAR files to $HAR_DIR:"
ls -la "$HAR_DIR"/*.har

echo ""
echo "Next: cd $ROOT && ohpm install"
echo "Release 包请用 release HAR，并更新 oh-package.json5 中 har 文件名。"
