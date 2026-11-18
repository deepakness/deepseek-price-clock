#!/bin/bash
# Builds "DeepSeek Price Clock.app" and ad-hoc signs it. Usage: ./build.sh
# Set DS_SIGN_IDENTITY=<name> to sign with a stable identity instead.
set -euo pipefail

cd "$(dirname "$0")"
APP="build/DeepSeek Price Clock.app"
ICONS="../icons"

# Ad-hoc signed by default: no certificate needed, no identity attached to the
# build, and it runs from /Applications on the Mac that built it. Set
# DS_SIGN_IDENTITY to any codesigning identity (for example one created in
# Keychain Access) if you want the signature to stay stable across rebuilds,
# which is what keeps notification permission and the login item attached.
IDENTITY="${DS_SIGN_IDENTITY:--}"

echo "Building"
swift build -c release

echo "Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/DeepSeekPriceClock "$APP/Contents/MacOS/DeepSeekPriceClock"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$ICONS/peak32.png" "$APP/Contents/Resources/peak32.png"
# The glyph ships as a plain resource so the app needs no build directory at
# runtime (the dev loop still reads it out of SwiftPM's resource bundle).

# AppIcon.icns from the 128 px art (iconutil needs the full ladder).
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
sips -z 16 16 "$ICONS/off128.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICONS/off128.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICONS/off128.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICONS/off128.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICONS/off128.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICONS/off128.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICONS/off128.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICONS/off128.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICONS/off128.png" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICONS/off128.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

if [ "$IDENTITY" = "-" ]; then
  echo "Signing ad-hoc (unsigned for Gatekeeper; see macos/README.md)"
else
  echo "Signing with $IDENTITY"
fi
codesign --force --sign "$IDENTITY" --identifier com.deepakness.deepseek-price-clock "$APP"
codesign --verify --verbose=2 "$APP"
echo "Ready: $APP"
