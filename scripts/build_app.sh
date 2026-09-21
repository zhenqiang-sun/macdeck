#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

BIN_STAGING="$PROJECT_DIR/.build/bin_staging"
mkdir -p "$BIN_STAGING"

echo "==> 编译 Apple Silicon (arm64) 架构 Release 二进制..."
swift build -c release --triple arm64-apple-macosx13.0 \
  -Xswiftc -Xfrontend -Xswiftc -load-resolved-plugin -Xswiftc -Xfrontend -Xswiftc /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib##SwiftUIMacros
cp .build/release/MacDeck "$BIN_STAGING/MacDeck_arm64"

echo "==> 编译 Intel (x86_64) 架构 Release 二进制..."
swift build -c release --triple x86_64-apple-macosx13.0 \
  -Xswiftc -Xfrontend -Xswiftc -load-resolved-plugin -Xswiftc -Xfrontend -Xswiftc /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib##SwiftUIMacros
cp .build/release/MacDeck "$BIN_STAGING/MacDeck_x86_64"

APP_DIR="$PROJECT_DIR/MacDeck.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> 组装 macOS Universal 2 .app bundle: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

echo "==> 使用 lipo 合成 Universal 2 (arm64 + x86_64) 通用二进制..."
lipo -create "$BIN_STAGING/MacDeck_arm64" "$BIN_STAGING/MacDeck_x86_64" -output "$MACOS/MacDeck"

# 复制 App 图标
if [ -f "Resources/AppIcon.icns" ]; then
    echo "==> 复制应用图标 AppIcon.icns..."
    cp "Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

# 复制多语言语言包 (Locales)
if [ -d "Resources/Locales" ]; then
    echo "==> 复制语言包 Resources/Locales..."
    cp -R "Resources/Locales" "$RESOURCES/"
fi

cat <<EOF > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacDeck</string>
    <key>CFBundleIdentifier</key>
    <string>com.agy.MacDeck</string>
    <key>CFBundleName</key>
    <string>MacDeck</string>
    <key>CFBundleDisplayName</key>
    <string>MacDeck</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "==> 赋予执行权限..."
chmod +x "$MACOS/MacDeck"

echo "==> 进行稳定标识代码签名 (Ad-Hoc with Designated Identifier)..."
codesign -s - --force --deep -r='designated => identifier "com.agy.MacDeck"' "$APP_DIR"

if [ -d "/Applications/MacDeck.app" ]; then
    echo "==> 同步更新至 /Applications/MacDeck.app..."
    rm -rf "/Applications/MacDeck.app"
    cp -R "$APP_DIR" "/Applications/MacDeck.app"
fi

echo "✅ 成功生成带专属图标与稳定签名的 MacDeck.app！"
