#!/usr/bin/env bash
#
#  在 macOS 上一键出包（未签名 ipa）
#  用法：chmod +x build_ipa.sh && ./build_ipa.sh
#
#  产物：build/PAN-unsigned.ipa
#  它不能直接装，需要用 Sideloadly / AltStore 用你自己的 Apple ID 签一次名。
#

set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "✗ 缺少 xcodegen。先执行： brew install xcodegen"
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "✗ 找不到 xcodebuild。确认已安装 Xcode 并执行过： sudo xcode-select -s /Applications/Xcode.app"
  exit 1
fi

echo "▸ 1/3 生成 Xcode 工程"
xcodegen generate

echo "▸ 2/3 编译 Release（关闭签名）"
xcodebuild \
  -project PAN.xcodeproj \
  -scheme PAN \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build > build.log 2>&1 || {
    echo "✗ 编译失败，最后 40 行日志："
    tail -n 40 build.log
    exit 1
  }

APP="build/Build/Products/Release-iphoneos/PAN.app"
if [ ! -d "$APP" ]; then
  echo "✗ 没找到编译产物：$APP"
  tail -n 40 build.log
  exit 1
fi

echo "▸ 3/3 打包 ipa"
rm -rf build/Payload build/PAN-unsigned.ipa
mkdir -p build/Payload
cp -R "$APP" build/Payload/
( cd build && zip -qry PAN-unsigned.ipa Payload )

SIZE=$(du -h build/PAN-unsigned.ipa | cut -f1)
echo ""
echo "✓ 出包完成"
echo "  文件：$(pwd)/build/PAN-unsigned.ipa  ($SIZE)"
echo ""
echo "  下一步（Windows 上也行）："
echo "  1. 装 Sideloadly 和「非 Microsoft Store 版」iTunes"
echo "  2. 把 ipa 拖进 Sideloadly，填 Apple ID，Start"
echo "  3. 手机上 设置 → 通用 → VPN与设备管理 → 信任该开发者"
