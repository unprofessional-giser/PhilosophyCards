#!/usr/bin/env bash
# 编译并打包成 macOS .app（不需要 Xcode，只需要 Swift 工具链）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="PhilosophyCards"
BUILD_DIR="$ROOT/build"
OUT_APP="$BUILD_DIR/哲思卡片.app"

# ---- 选择 Swift 编译器 -------------------------------------------------------
# 优先使用独立安装的 Swift 工具链（系统 Command Line Tools 有时会出问题），
# 也可以用 SWIFTC=/path/to/swiftc ./build.sh 指定。
find_swiftc() {
    if [[ -n "${SWIFTC:-}" ]]; then
        echo "$SWIFTC"
        return
    fi
    for candidate in "$HOME"/Library/Developer/SwiftToolchains/*/usr/bin/swiftc; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return
        fi
    done
    xcrun --find swiftc
}

SWIFTC="$(find_swiftc)"
SDK="$(xcrun --show-sdk-path)"

# UNIVERSAL=1 同时编译 Apple Silicon 和 Intel，方便发给别人
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    ARCHS=(arm64 x86_64)
else
    ARCH="$(uname -m)"
    [[ "$ARCH" == "arm64" ]] || ARCH="x86_64"
    ARCHS=("$ARCH")
fi

echo "→ 编译器: $SWIFTC"
echo "→ SDK:    $SDK"

# 在临时目录里构建并签名，最后再拷进 build/。
# 项目如果放在 iCloud 同步的目录（桌面等），系统会不断给 .app 加 FinderInfo，
# codesign 会因此失败、把 App 变成未签名（双击打不开）。
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/philosophycards-build.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

APP="$WORK_DIR/哲思卡片.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCES=()
while IFS= read -r file; do
    SOURCES+=("$file")
done < <(find "$ROOT/Sources/PhilosophyCards" -name '*.swift' -print | sort)

if [[ ${#ARCHS[@]} -eq 1 ]]; then
    "$SWIFTC" \
        -O \
        -parse-as-library \
        -target "${ARCHS[0]}-apple-macos13.0" \
        -sdk "$SDK" \
        -o "$APP/Contents/MacOS/$APP_NAME" \
        "${SOURCES[@]}"
else
    SLICES=()
    for arch in "${ARCHS[@]}"; do
        slice="$WORK_DIR/philosophycards-$arch"
        echo "→ 编译 $arch"
        "$SWIFTC" \
            -O \
            -parse-as-library \
            -target "${arch}-apple-macos13.0" \
            -sdk "$SDK" \
            -o "$slice" \
            "${SOURCES[@]}"
        SLICES+=("$slice")
    done
    lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/$APP_NAME"
fi

# ---- 打包资源与 Info.plist --------------------------------------------------
cp "$ROOT/Sources/PhilosophyCards/Resources/concepts.json" "$APP/Contents/Resources/concepts.json"
cp "$ROOT/Support/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# ---- 签名 -------------------------------------------------------------------
sign_app() {
    local attempt
    for attempt in 1 2 3; do
        xattr -cr "$APP" 2>/dev/null || true
        if codesign --force --sign - "$APP" >/dev/null 2>&1 \
            && codesign --verify "$APP" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.3
    done
    return 1
}

if sign_app; then
    echo "✓ 已签名（ad-hoc）"
else
    echo "⚠️  签名失败，Finder 双击可能打不开。" >&2
fi

# ---- 拷贝到 build/ ----------------------------------------------------------
mkdir -p "$BUILD_DIR"
rm -rf "$OUT_APP"
ditto --norsrc --noextattr "$APP" "$OUT_APP"

if codesign --verify "$OUT_APP" >/dev/null 2>&1; then
    echo "✓ 构建完成: $OUT_APP"
else
    echo "⚠️  拷贝后签名校验失败（通常是 iCloud 同步导致的扩展属性）。" >&2
    echo "    把项目移到非 iCloud 目录（例如 ~/Developer）再构建即可。" >&2
    echo "    已生成: $OUT_APP" >&2
fi

if [[ "${1:-}" == "--run" ]]; then
    echo "→ 启动中…"
    pkill -x "$APP_NAME" 2>/dev/null || true
    open "$OUT_APP"
fi
