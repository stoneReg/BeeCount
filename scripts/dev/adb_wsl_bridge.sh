#!/usr/bin/env bash
# WSL2 下复用 Windows 侧 adb，使 flutter 能识别 USB 连接的真机。
set -euo pipefail

WIN_ADB="${WIN_ADB:-/mnt/c/Users/hfuul/AppData/Local/Microsoft/WinGet/Packages/Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe/platform-tools/adb.exe}"
SDK_ADB="${SDK_ADB:-/root/Android/Sdk/platform-tools/adb}"

if [[ ! -f "$WIN_ADB" ]]; then
  echo "❌ 未找到 Windows adb: $WIN_ADB"
  echo "   请安装 Google Platform Tools，或设置 WIN_ADB 环境变量"
  exit 1
fi

if [[ ! -f "$SDK_ADB.orig" ]]; then
  cp "$SDK_ADB" "$SDK_ADB.orig"
  echo "已备份 SDK adb -> ${SDK_ADB}.orig"
fi

cat > "$SDK_ADB" <<EOF
#!/usr/bin/env bash
exec "$WIN_ADB" "\$@"
EOF
chmod +x "$SDK_ADB"

/root/Android/Sdk/platform-tools/adb kill-server 2>/dev/null || true
"$WIN_ADB" start-server >/dev/null 2>&1 || true

echo "ADB: flutter 将通过 Windows adb 访问真机"
"$WIN_ADB" devices -l
