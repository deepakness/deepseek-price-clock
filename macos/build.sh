#!/bin/bash
# Builds "DeepSeek Price Clock.app" and signs it with the local self-signed
# identity. Usage: ./build.sh
set -euo pipefail

cd "$(dirname "$0")"
APP="build/DeepSeek Price Clock.app"
ICONS="../icons"

# Prefer a dedicated identity, fall back to the machine's Apple Development one,
# and let DS_SIGN_IDENTITY override both. A stable identity keeps the notification
# permission attached to the app across rebuilds.
IDENTITY="${DS_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o '"DeepSeek Price Clock Dev"' | head -1 | tr -d '"' || true)
fi
if [ -z "$IDENTITY" ]; then
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"' || true)
fi
if [ -z "$IDENTITY" ]; then
  cat >&2 <<MSG
No code signing identity found.

Create one once, then re-run this script:
  1. Open Keychain Access → menu Certificate Assistant → Create a Certificate…
  2. Name: DeepSeek Price Clock Dev
  3. Identity Type: Self Signed Root · Certificate Type: Code Signing
  4. Create, then Done. (macOS may ask to trust it the first time you sign.)

Alternatively set DS_SIGN_IDENTITY to any existing codesigning identity.
MSG
  exit 1
fi

echo "Building"
swift build -c release

echo "Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/DeepSeekPriceClock "$APP/Contents/MacOS/DeepSeekPriceClock"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$ICONS"/off*.png "$ICONS"/peak*.png "$APP/Contents/Resources/"

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

echo "Signing with $IDENTITY"
codesign --force --sign "$IDENTITY" --identifier com.deepakness.deepseek-price-clock "$APP"
codesign --verify --verbose=2 "$APP"
echo "Ready: $APP"
