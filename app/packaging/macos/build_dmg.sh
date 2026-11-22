#!/usr/bin/env bash
# Packages the macOS release build into a .dmg, optionally signing it with a
# Developer ID certificate and notarizing it with Apple.
#
#   cd app && flutter build macos --release && packaging/macos/build_dmg.sh
#
# Environment:
#   MACOS_SIGN_IDENTITY   "Developer ID Application: Name (TEAMID)" — sign when set
#   NOTARIZE=1            submit to Apple's notary service and staple the ticket
#   ASC_KEY_PATH, APP_STORE_CONNECT_KEY_IDENTIFIER, APP_STORE_CONNECT_ISSUER_ID
#                         App Store Connect API key used for notarization
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$APP_DIR"

APP="build/macos/Build/Products/Release/Color Contrast Checker.app"
DIST="$APP_DIR/../dist"
DMG="$DIST/ColorContrastChecker-macOS.dmg"
ENTITLEMENTS="macos/Runner/Release.entitlements"
IDENTITY="${MACOS_SIGN_IDENTITY:-}"

[ -d "$APP" ] || { echo "Missing $APP — run 'flutter build macos --release' first." >&2; exit 1; }
mkdir -p "$DIST"

if [ -n "$IDENTITY" ]; then
  echo "==> Signing with: $IDENTITY"
  # Sign nested code first (inside-out), then the app with hardened runtime.
  find "$APP/Contents/Frameworks" -depth \( -name "*.framework" -o -name "*.dylib" \) -print0 |
    while IFS= read -r -d '' item; do
      codesign --force --options runtime --timestamp --sign "$IDENTITY" "$item"
    done
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  echo "==> MACOS_SIGN_IDENTITY not set: building an unsigned (ad-hoc) DMG"
fi

echo "==> Creating DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Color Contrast Checker" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

if [ -n "$IDENTITY" ]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
fi

if [ "${NOTARIZE:-}" = "1" ]; then
  echo "==> Notarizing"
  xcrun notarytool submit "$DMG" \
    --key "$ASC_KEY_PATH" \
    --key-id "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" || true
fi

echo "==> $DMG"
