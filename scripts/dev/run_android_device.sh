#!/usr/bin/env bash
# 本地真机调试：桥接 Windows adb 后 flutter run（dev 风味，可热重载）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH="/opt/flutter/bin:$PATH"

FLAVOR="${FLAVOR:-dev}"
MODE="${MODE:-debug}"

source "$ROOT/scripts/dev/adb_wsl_bridge.sh"

cd "$ROOT"
flutter pub get

mapfile -t ANDROID_DEVICES < <(flutter devices 2>/dev/null | grep -E '• android' | awk -F '•' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)

DEVICE_ID="${ANDROID_DEVICES[0]:-}"
if [[ -z "$DEVICE_ID" ]]; then
  # 回退：解析 flutter devices --machine
  DEVICE_ID="$(flutter devices --machine 2>/dev/null | python3 -c "
import json,sys
items=json.load(sys.stdin)
for d in items:
    p=d.get('targetPlatform','')
    if p.startswith('android'):
        print(d['id']); break
" 2>/dev/null || true)"
fi

if [[ -z "${DEVICE_ID:-}" ]]; then
  echo ""
  echo "❌ 未检测到 Android 真机。请确认："
  echo "   1. 手机已开启「开发者选项 → USB 调试」"
  echo "   2. USB 连接电脑并在手机上点「允许调试」"
  echo "   3. 在 Windows PowerShell 执行: adb devices （应能看到 device）"
  echo ""
  echo "无线调试："
  echo "   adb pair <ip>:<pair_port> && adb connect <ip>:5555"
  exit 1
fi

echo "▶ 启动真机调试: flavor=$FLAVOR mode=$MODE device=$DEVICE_ID"
exec flutter run \
  --flavor "$FLAVOR" \
  --$MODE \
  -d "$DEVICE_ID" \
  --dart-define=GITHUB_REPO_OWNER=stoneReg \
  --dart-define=GITHUB_REPO_NAME=BeeCount
