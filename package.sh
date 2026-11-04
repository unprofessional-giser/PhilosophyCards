#!/usr/bin/env bash
# 打一个可以直接发给别人的 Universal 包（Apple Silicon + Intel）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

UNIVERSAL=1 ./build.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
DIST="$ROOT/dist"
STAGE="$DIST/哲思卡片"

rm -rf "$DIST"
mkdir -p "$STAGE"

ditto --norsrc --noextattr "$ROOT/build/哲思卡片.app" "$STAGE/哲思卡片.app"
cp "$ROOT/Support/安装说明.txt" "$STAGE/安装说明.txt"

ZIP="$DIST/哲思卡片-macOS-$VERSION.zip"
ditto -c -k --norsrc --noextattr --keepParent "$STAGE" "$ZIP"

echo
echo "✓ 分享包: $ZIP"
echo "  架构: $(lipo -archs "$STAGE/哲思卡片.app/Contents/MacOS/PhilosophyCards")"
echo "  大小: $(du -sh "$ZIP" | cut -f1)"
