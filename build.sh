#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
  SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
else
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
fi
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx14.0"
BUILD="$ROOT/build"
APP="$ROOT/../衣镜.app"

killall "衣镜" 2>/dev/null || true

rm -rf "$BUILD" "$APP"
mkdir -p "$BUILD/icon.iconset" "$BUILD/models" "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -sdk "$SDK" -target "$TARGET" -O -framework AppKit \
  -o "$BUILD/MakeIcon" "$ROOT/Tools/MakeIcon.swift"
"$BUILD/MakeIcon" "$BUILD/icon-1024.png"

swiftc -sdk "$SDK" -target "$TARGET" -O -framework AppKit \
  -o "$BUILD/MakeModels" "$ROOT/Tools/MakeModels.swift"
"$BUILD/MakeModels" "$BUILD/models"
cp "$BUILD/models/"*.png "$APP/Contents/Resources/"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$BUILD/icon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

swiftc -sdk "$SDK" -target "$TARGET" -swift-version 5 -O -whole-module-optimization \
  -framework AppKit \
  -framework SwiftUI \
  -framework AVKit \
  -framework AVFoundation \
  -framework ImageIO \
  -framework CoreGraphics \
  -framework UniformTypeIdentifiers \
  -o "$APP/Contents/MacOS/衣镜" \
  "$ROOT"/Sources/*.swift

cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
"$APP/Contents/MacOS/衣镜" --self-test
echo "已生成 $APP"
