#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Perfect Passwords Grabber"
BINARY_NAME="PasswordGen"
VERSION="1.6"
DMG_NAME="PerfectPasswordsGrabber-v${VERSION}.dmg"
STAGING_DIR="build/dmg_staging"
APP_BUNDLE="${STAGING_DIR}/${APP_NAME}.app"
ENTITLEMENTS="PasswordGen.entitlements"
APP_ZIP="build/${BINARY_NAME}-v${VERSION}-app.zip"

# Developer ID identity and notarytool keychain profile, matching the sibling app
# repos. A notarytool profile cannot be exported, so a new Mac needs this once
# before its first release:
#   xcrun notarytool store-credentials notarytool --apple-id <email> --team-id T9RLNAXPWU
# Set NOTARY_PROFILE to use another.
IDENTITY="Developer ID Application: Seven Morris (T9RLNAXPWU)"
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool}"

fail() { echo "" >&2; echo "✗ $*" >&2; exit 1; }

echo "========================================"
echo "  ${APP_NAME} v${VERSION} — Distribution"
echo "========================================"
echo ""

# Preflight ────────────────────────────────────────────────────────────────────
# Everything that can fail for an environmental reason is checked up front, so a
# missing credential surfaces before a build rather than minutes into one.
echo "Preflight..."
for cmd in swift codesign hdiutil xcrun plutil; do
    command -v "$cmd" >/dev/null 2>&1 || fail "required command not found: $cmd"
done
[[ -f "$ENTITLEMENTS" ]] || fail "entitlements file not found: $ENTITLEMENTS"
plutil -lint "$ENTITLEMENTS" >/dev/null || fail "$ENTITLEMENTS is not a valid plist"
security find-identity -v -p codesigning 2>/dev/null | grep -qF "$IDENTITY" \
    || fail "signing identity not found in the keychain: $IDENTITY"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "notarytool profile '$NOTARY_PROFILE' is missing, rejected or unreachable — create it with: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <email> --team-id T9RLNAXPWU"
echo "✓ Toolchain, signing identity and notarytool profile all present"
echo ""

# Clean
rm -rf build/
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Build
echo "Building release binary..."
swift build -c release 2>&1 | grep -v "^Build complete" || true
[[ -f ".build/release/${BINARY_NAME}" ]] || fail "swift build produced no binary"
echo "✓ Build complete"
echo ""

# Copy binary
cp ".build/release/${BINARY_NAME}" "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"

# Copy icon
cp "assets/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${BINARY_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.sevmorris.perfectpasswordsgrabber</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

# Update README download link
echo "Updating README download link to v${VERSION}..."
sed -i '' "s|Perfect Passwords Grabber v[0-9][0-9.]*|Perfect Passwords Grabber v${VERSION}|g" README.md

# Code sign ────────────────────────────────────────────────────────────────────
# Developer ID with the hardened runtime and a secure timestamp. All three are
# required for notarization; an ad-hoc signature cannot be notarized at all.
echo "Signing with Developer ID..."
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" \
    "${APP_BUNDLE}" || fail "codesign failed"
codesign --verify --strict --verbose=2 "${APP_BUNDLE}" 2>&1 | tail -2
echo "✓ Signed"
echo ""

# Notarize the app ─────────────────────────────────────────────────────────────
# Stapling only the DMG leaves the app unstapled the moment it is dragged out to
# Applications, which is the form anyone actually runs. Gatekeeper still passes
# it, by asking Apple instead — but that needs a working network on first
# launch. So the app gets its own round trip and its own ticket, before the DMG
# is built around it. The ticket covers this exact cdhash, so this has to follow
# codesigning and precede the DMG.
echo "Notarizing the app (first of two round trips)..."
rm -f "$APP_ZIP"
ditto -c -k --keepParent "${APP_BUNDLE}" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --wait --keychain-profile "$NOTARY_PROFILE" \
    || fail "app notarization failed"
xcrun stapler staple "${APP_BUNDLE}" || fail "stapling the app failed"
xcrun stapler validate "${APP_BUNDLE}" >/dev/null || fail "the app has no valid stapled ticket"
rm -f "$APP_ZIP"
echo "✓ App notarized and stapled"
echo ""

# Staging: README and Applications symlink
cp README.txt "${STAGING_DIR}/README.txt"
ln -s /Applications "${STAGING_DIR}/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}" > /dev/null
[[ -f "${DMG_NAME}" ]] || fail "hdiutil produced no DMG"

# Sign the DMG itself, not just the app inside it. Without this the image has no
# usable signature of its own, so spctl cannot assess it even once the
# notarization ticket is stapled. Signing must happen before notarization;
# stapling afterwards does not disturb the signature.
codesign --force --timestamp --sign "$IDENTITY" "${DMG_NAME}" || fail "signing the DMG failed"
echo "✓ ${DMG_NAME} (signed)"
echo ""

# Notarize ─────────────────────────────────────────────────────────────────────
# Apple staples the ticket to the DMG, so Gatekeeper clears the app on a machine
# that has never seen it and without a network round trip at first launch.
echo "Notarizing the DMG (second round trip)..."
xcrun notarytool submit "${DMG_NAME}" --wait --keychain-profile "$NOTARY_PROFILE" \
    || fail "notarization failed — run 'xcrun notarytool log <submission-id> --keychain-profile $NOTARY_PROFILE' for the reason"
xcrun stapler staple "${DMG_NAME}" || fail "stapling failed"
echo "✓ Notarized and stapled"
echo ""

# Verify ───────────────────────────────────────────────────────────────────────
# Checks the shipping artifact rather than the inputs that produced it: a DMG
# that is not properly stapled is exactly the failure users would hit first.
echo "Verifying..."
xcrun stapler validate "${DMG_NAME}" >/dev/null || fail "the DMG has no valid stapled ticket"
spctl --assess --type open --context context:primary-signature "${DMG_NAME}" 2>&1 \
    || fail "Gatekeeper rejected the DMG"

# The DMG passing is necessary but not sufficient: what a user actually launches
# is the app inside it, so assess that too and require notarization specifically
# — a merely Developer ID-signed app would still be refused on a first launch.
VERIFY_MOUNT="build/verify_mount"
rm -rf "$VERIFY_MOUNT" && mkdir -p "$VERIFY_MOUNT"
hdiutil attach "${DMG_NAME}" -nobrowse -readonly -mountpoint "$VERIFY_MOUNT" -quiet \
    || fail "could not mount the finished DMG"
ASSESS=$(spctl --assess --type exec -vv "$VERIFY_MOUNT/${APP_NAME}.app" 2>&1 || true)
DMG_VERSION=$(defaults read "$PWD/$VERIFY_MOUNT/${APP_NAME}.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unreadable")
# The ticket on the copy that actually ships, not on the build product that was
# stapled — those are the two that can drift apart. Captured before the detach
# so the volume is never left mounted on a failure.
if xcrun stapler validate "$VERIFY_MOUNT/${APP_NAME}.app" >/dev/null 2>&1; then
    DMG_APP_STAPLED=1
else
    DMG_APP_STAPLED=0
fi
hdiutil detach "$VERIFY_MOUNT" -quiet || true
[[ "$DMG_APP_STAPLED" == 1 ]] \
    || fail "the app inside the DMG carries no notarization ticket of its own"
grep -q "source=Notarized Developer ID" <<<"$ASSESS" \
    || fail "the app in the DMG is not recognised as notarized: $ASSESS"
[[ "$DMG_VERSION" == "$VERSION" ]] \
    || fail "DMG version mismatch: expected $VERSION, got $DMG_VERSION"
echo "✓ DMG signed and stapled; app inside is $DMG_VERSION, notarized and stapled in its own right"
echo ""
echo "Done."
