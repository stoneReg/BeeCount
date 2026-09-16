#!/usr/bin/env bash
# 安装本地 prod Release APK 到已连接的真机
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/scripts/dev/adb_wsl_bridge.sh"

APK="${1:-$ROOT/build/app/outputs/apk/prod/release/app-prod-release-v0.0.1(1).apk}"
if [[ ! -f "$APK" ]]; then
  APK="$ROOT/build/app/outputs/flutter-apk/app-prod-release.apk"
fi
if [[ ! -f "$APK" ]]; then
  echo "❌ 未找到 APK，请先运行: bash scripts/dev/build_apk_release.sh"
  exit 1
fi

DEVICES="$("$WIN_ADB" devices | awk 'NR>1 && $2=="device"{print $1}')"
if [[ -z "$DEVICES" ]]; then
  echo "❌ 无已连接真机，请先 USB 连接并开启调试"
  exit 1
fi

echo "▶ 安装: $APK"
"$WIN_ADB" install -r "$APK"
