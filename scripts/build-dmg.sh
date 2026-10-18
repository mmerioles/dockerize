#!/usr/bin/env bash
# Builds a universal Dockerize.app and packs it into dist/Dockerize.dmg.
#   scripts/build-dmg.sh [version]      (version defaults to 0.1.0)
set -euo pipefail

VERSION="${1:-0.1.0}"
VERSION="${VERSION#v}"
BUILD="${GITHUB_RUN_NUMBER:-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Dockerize.app"
cd "$ROOT"

echo "==> Building Dockerize $VERSION (universal, release)"
# One arch at a time: the combined --arch build trips over SwiftTerm's build plugin.
for arch in arm64 x86_64; do
  swift build -c release --arch "$arch"
done
BIN="$DIST/Dockerize-universal"
mkdir -p "$DIST"
lipo -create -output "$BIN" \
  "$(swift build -c release --arch arm64 --show-bin-path)/Dockerize" \
  "$(swift build -c release --arch x86_64 --show-bin-path)/Dockerize"

echo "==> Assembling $APP"
rm -rf "$APP" "$DIST/Dockerize.dmg"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$BIN" "$APP/Contents/MacOS/Dockerize"
BIN="$APP/Contents/MacOS/Dockerize"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" scripts/Info.plist > "$APP/Contents/Info.plist"

echo "==> Making the app icon"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
"$BIN" --export-icon "$WORK/icon.png"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Signing (ad hoc)"
codesign --force --deep --sign - "$APP"

echo "==> Creating the disk image"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Dockerize" -srcfolder "$STAGE" -ov -format UDZO "$DIST/Dockerize.dmg" >/dev/null

echo "==> Done: $DIST/Dockerize.dmg"
