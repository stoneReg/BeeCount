#!/usr/bin/env bash
# 本地打包 prod Release APK（使用 android/key.properties 签名）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH="/opt/flutter/bin:$PATH"

cd "$ROOT"

if [[ ! -f android/key.properties ]]; then
  echo "❌ 缺少 android/key.properties，请先配置签名 keystore"
  exit 1
fi

flutter pub get

VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
BUILD_NUM="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f2)"
TAG="v${VERSION}-local"

echo "▶ 构建 prod Release APK (version=${VERSION}+${BUILD_NUM})"
flutter build apk --release --flavor prod \
  --dart-define=CI_VERSION="$TAG" \
  --dart-define=GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo local)" \
  --dart-define=BUILD_TIME="$(date +%s)" \
  --dart-define=GITHUB_REPO_OWNER=stoneReg \
  --dart-define=GITHUB_REPO_NAME=BeeCount

APK_DIR="build/app/outputs/apk/prod/release"
echo ""
echo "✅ 构建完成，产物目录: $APK_DIR"
ls -lh "$APK_DIR"/*.apk 2>/dev/null || ls -lh "$APK_DIR"/
