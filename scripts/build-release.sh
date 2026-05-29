#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# HushBar release build script
# Run from the repo root on a Mac:  bash scripts/build-release.sh
#
# Produces in dist/:
#   HushBar-<version>.zip   — drag-to-Applications, unsigned (quick share)
#   HushBar-<version>.dmg   — requires create-dmg (brew install create-dmg)
#
# For a signed/notarized build you must have:
#   - A paid Apple Developer Program membership
#   - A Developer ID Application certificate in your keychain
#   - A notarytool keychain profile  (see DISTRIBUTION.md §0)
#   Set SIGN=1 to enable signing and notarization.
# ---------------------------------------------------------------------------

VERSION=$(defaults read "$(pwd)/Support/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
APP_NAME="HushBar"
SCHEME="hushBar"
DERIVED_DATA="build"
APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST="dist"
ZIP_NAME="$APP_NAME-$VERSION.zip"
DMG_NAME="$APP_NAME-$VERSION.dmg"

SIGN="${SIGN:-0}"
NOTARIZE_PROFILE="${AC_PROFILE:-AC_PROFILE}"

echo "==> Building $APP_NAME $VERSION"
xcodegen generate
xcodebuild \
    -project hushBar.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    clean build \
    | xcpretty 2>/dev/null || cat

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: build did not produce $APP_PATH"
    exit 1
fi

mkdir -p "$DIST"

# --- optional: sign + notarize -----------------------------------------------
if [ "$SIGN" = "1" ]; then
    echo "==> Signing with Developer ID"
    codesign --deep --force --options runtime \
        --sign "Developer ID Application" \
        "$APP_PATH"

    echo "==> Verifying signature"
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"

    echo "==> Notarizing (this takes a few minutes)"
    NOTARIZE_ZIP="$DIST/$APP_NAME-notarize.zip"
    ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
    xcrun notarytool submit "$NOTARIZE_ZIP" \
        --keychain-profile "$NOTARIZE_PROFILE" --wait
    xcrun stapler staple "$APP_PATH"
    rm -f "$NOTARIZE_ZIP"
    spctl -a -vvv -t install "$APP_PATH"
fi

# --- zip (drag-to-Applications) ----------------------------------------------
echo "==> Creating $ZIP_NAME"
rm -f "$DIST/$ZIP_NAME"
ditto -c -k --keepParent "$APP_PATH" "$DIST/$ZIP_NAME"
echo "    $DIST/$ZIP_NAME  ($(du -sh "$DIST/$ZIP_NAME" | cut -f1))"

# --- DMG (optional, requires create-dmg) -------------------------------------
if command -v create-dmg &>/dev/null; then
    echo "==> Creating $DMG_NAME"
    rm -f "$DIST/$DMG_NAME"
    create-dmg \
        --volname "$APP_NAME" \
        --window-size 520 320 \
        --icon "$APP_NAME.app" 140 150 \
        --app-drop-link 380 150 \
        "$DIST/$DMG_NAME" \
        "$APP_PATH"

    if [ "$SIGN" = "1" ]; then
        echo "==> Notarizing DMG"
        xcrun notarytool submit "$DIST/$DMG_NAME" \
            --keychain-profile "$NOTARIZE_PROFILE" --wait
        xcrun stapler staple "$DIST/$DMG_NAME"
    fi

    SHA=$(shasum -a 256 "$DIST/$DMG_NAME" | awk '{print $1}')
    echo "    $DIST/$DMG_NAME  ($(du -sh "$DIST/$DMG_NAME" | cut -f1))"
    echo "    SHA-256: $SHA"
    echo ""
    echo "    Paste that SHA-256 into Casks/hushbar.rb before pushing to your tap."
else
    echo "    (Skipping DMG — install create-dmg with: brew install create-dmg)"
fi

echo ""
echo "Done. Files in $DIST/:"
ls -lh "$DIST/"
