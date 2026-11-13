#!/usr/bin/env bash
# Capture AGC screenshots (1080x1920, 9:16) from running HarmonyOS emulator.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-/Users/liminglin/Downloads/landplaceapp/agc-screenshots}"
TOOLCHAIN="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains"
export PATH="$TOOLCHAIN:$PATH"
HAP="${HAP:-$ROOT/entry/build/default/outputs/default/entry-default-signed.hap}"
BUNDLE="com.lanplace.bluescopes"

TARGET="${HDC_TARGET:-}"
if [[ -z "$TARGET" ]]; then
  TARGET="$(hdc list targets 2>/dev/null | awk 'NR==1{print $1}')"
fi
if [[ -z "$TARGET" || "$TARGET" == "[Empty]" ]]; then
  echo "error: start DevEco emulator first" >&2
  exit 1
fi
T="-t $TARGET"
export T OUT HAP

python3 - <<'PY'
import json, os, re, subprocess, time
from pathlib import Path
from PIL import Image

T = os.environ["T"]
OUT = Path(os.environ.get("OUT", "/Users/liminglin/Downloads/landplaceapp/agc-screenshots"))
HAP = os.environ.get("HAP", "")
BUNDLE = "com.lanplace.bluescopes"
TMP = "/data/local/tmp/agc_snap.jpeg"
TARGET = (1080, 1920)
LAYOUT_DEV = "/data/local/tmp/agc_layout.json"
LAYOUT_LOCAL = "/tmp/agc_layout.json"


def hdc(*args, check=False):
    return subprocess.run(["hdc", T, *args], capture_output=check, text=True)


def pull_layout():
    hdc("shell", "uitest", "dumpLayout", "-p", LAYOUT_DEV)
    subprocess.run(["hdc", T, "file", "recv", LAYOUT_DEV, LAYOUT_LOCAL], check=True, capture_output=True)
    with open(LAYOUT_LOCAL, encoding="utf-8") as f:
        return json.load(f)


def find_clickable_text(layout, *needles):
    hits = []

    def walk(node):
        if not isinstance(node, dict):
            return
        a = node.get("attributes", {})
        text = (a.get("originalText") or a.get("text") or "").strip()
        if a.get("clickable") == "true" and text:
            for n in needles:
                if n in text:
                    m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", a.get("bounds", ""))
                    if m:
                        x1, y1, x2, y2 = map(int, m.groups())
                        hits.append((text, (x1 + x2) // 2, (y1 + y2) // 2))
        for c in node.get("children") or []:
            walk(c)

    walk(layout)
    return hits


def click(x, y, wait=1.5):
    hdc("shell", "uitest", "uiInput", "click", str(x), str(y))
    time.sleep(wait)


def snap_png(path: Path):
    """Fit full emulator frame into 1080x1920 (9:16) with letterbox — no center crop."""
    hdc("shell", "snapshot_display", "-f", TMP)
    j = path.with_suffix(".jpeg")
    subprocess.run(["hdc", T, "file", "recv", TMP, str(j)], check=True, capture_output=True)
    im = Image.open(j).convert("RGB")
    j.unlink(missing_ok=True)
    tw, th = TARGET
    w, h = im.size
    scale = min(tw / w, th / h)
    nw, nh = int(w * scale), int(h * scale)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (tw, th), (255, 255, 255))
    canvas.paste(im, ((tw - nw) // 2, (th - nh) // 2))
    canvas.save(path, "PNG", optimize=True)
    print(f"wrote {path} {path.stat().st_size // 1024} KB (src {w}x{h} fit scale {scale:.3f})")


def start_app():
    hdc("shell", "aa", "start", "-a", "EntryAbility", "-b", BUNDLE)
    time.sleep(2)


def agree_privacy_if_shown():
    layout = pull_layout()
    for text, x, y in find_clickable_text(layout, "同意并继续"):
        print(f"tap privacy agree: {text} @ {x},{y}")
        click(x, y, 2.5)
        return True
    return False


def tap_first(layout, *needles, wait=1.5):
    for text, x, y in find_clickable_text(layout, *needles):
        print(f"tap: {text} @ {x},{y}")
        click(x, y, wait)
        return True
    return False


OUT.mkdir(parents=True, exist_ok=True)
for f in OUT.glob("*.png"):
    f.unlink()

# --- 05 隐私弹窗：全新安装，不点同意 ---
if HAP and Path(HAP).is_file():
    hdc("shell", "bm", "uninstall", "-n", BUNDLE)
    hdc("install", "-r", HAP)
start_app()
snap_png(OUT / "05-隐私政策弹窗.png")

# --- 01~04：同意隐私 → 回首页 → 再进附近设备 ---
agree_privacy_if_shown()
time.sleep(1)
layout = pull_layout()
# 同意后默认进入 HomeInventory，先返回 Home
if not tap_first(layout, "返回", wait=1.5):
    click(124, 200, 1.5)
snap_png(OUT / "01-首页.png")

layout = pull_layout()
tap_first(layout, "发现附近设备", wait=3.5)
layout = pull_layout()
tap_first(layout, "允许", "Allow", "使用期间允许", wait=1.5)
snap_png(OUT / "02-附近设备-进入.png")
time.sleep(5)
snap_png(OUT / "03-附近设备-已发现.png")

layout = pull_layout()
tap_first(layout, "从列表选择", wait=1.5)
snap_png(OUT / "04-设备选择列表.png")

layout = pull_layout()
picked = False
for text, x, y in find_clickable_text(layout, "键盘", "温湿度", "打印机", "客厅"):
    print(f"tap device: {text} @ {x},{y}")
    click(x, y, 1.5)
    picked = True
    break
if picked:
    snap_png(OUT / "06-设备详情.png")

print("done", OUT)
PY
