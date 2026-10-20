#!/bin/bash
# swift build でビルドし、build/OLEDGuard.app を組み立てて ad-hoc 署名する。
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP_NAME="OLEDGuard"
APP="build/${APP_NAME}.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"
echo "作成しました: $APP"
