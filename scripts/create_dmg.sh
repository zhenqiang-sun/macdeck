#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

APP_PATH="$PROJECT_DIR/MacDeck.app"
VERSION="1.1.0"
DMG_NAME="MacDeck-${VERSION}.dmg"
STAGING_DIR="$PROJECT_DIR/.dmg_staging"

if [ ! -d "$APP_PATH" ]; then
    echo "==> MacDeck.app 不存在，正在先执行编译打包..."
    ./scripts/build_app.sh
fi

echo "==> 准备 DMG 打包临时目录: $STAGING_DIR"
rm -rf "$STAGING_DIR" "$PROJECT_DIR/$DMG_NAME"
mkdir -p "$STAGING_DIR"

echo "==> 复制应用包至临时目录..."
cp -R "$APP_PATH" "$STAGING_DIR/"

echo "==> 创建 /Applications 快捷链接..."
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> 使用 hdiutil 生成压缩格式 DMG: $DMG_NAME..."
hdiutil create -volname "MacDeck" \
               -srcfolder "$STAGING_DIR" \
               -ov \
               -format UDZO \
               "$PROJECT_DIR/$DMG_NAME"

rm -rf "$STAGING_DIR"

echo "✅ 成功生成发布镜像: $PROJECT_DIR/$DMG_NAME"
ls -lh "$PROJECT_DIR/$DMG_NAME"
