#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

NEW_VERSION="$1"
if [ -z "$NEW_VERSION" ]; then
    echo "❌ 错误: 请指定新版本号！例如: ./scripts/bump_version.sh 1.3.0"
    exit 1
fi

OLD_VERSION="$(tr -d '[:space:]' < "$PROJECT_DIR/VERSION")"
echo "==> 准备将版本从 v${OLD_VERSION} 升级至 v${NEW_VERSION}..."

# 1. 更新 SSOT VERSION 文件
echo "$NEW_VERSION" > "$PROJECT_DIR/VERSION"
echo "✓ 更新 VERSION 文件为: $NEW_VERSION"

# 2. 编译打包 Universal 2 .app
echo "==> 执行完整 Universal 2 打包..."
./scripts/build_app.sh

# 3. 生成 DMG
echo "==> 生成 DMG 安装镜像..."
./scripts/create_dmg.sh

# 4. 计算 SHA256 并更新 Homebrew Cask
DMG_FILE="$PROJECT_DIR/MacDeck-${NEW_VERSION}.dmg"
if [ -f "$DMG_FILE" ]; then
    SHA256="$(shasum -a 256 "$DMG_FILE" | awk '{print $1}')"
    echo "✓ 新 DMG SHA256: $SHA256"
    
    CASK_FILE="$PROJECT_DIR/Casks/macdeck.rb"
    if [ -f "$CASK_FILE" ]; then
        sed -i '' "s/version \".*\"/version \"${NEW_VERSION}\"/" "$CASK_FILE"
        sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" "$CASK_FILE"
        echo "✓ 自动更新 Casks/macdeck.rb 中的版本与 sha256 校验和"
    fi
fi

echo ""
echo "🎉 版本升级完成！"
echo "👉 请记得在 CHANGELOG.md 中添加 [${NEW_VERSION}] 更新日志。"
echo "👉 确认后执行 git commit 和 git tag v${NEW_VERSION} 即可发布！"
