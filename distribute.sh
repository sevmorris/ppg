#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Perfect Password Grabber"
BINARY_NAME="PasswordGen"
VERSION="1.0"
DMG_NAME="PerfectPasswordGrabber-v${VERSION}.dmg"
STAGING_DIR="build/dmg_staging"
APP_BUNDLE="${STAGING_DIR}/${APP_NAME}.app"

echo "========================================"
echo "  ${APP_NAME} v${VERSION} — Distribution"
echo "========================================"
echo ""

# Clean
rm -rf build/
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Build
echo "Building release binary..."
swift build -c release 2>&1 | grep -v "^Build complete" || true
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
    <string>com.sevmorris.perfectpasswordgrabber</string>
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

# Ad-hoc code sign
echo "Signing..."
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null
echo "✓ Signed"
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
echo "✓ ${DMG_NAME}"
echo ""
echo "Done."
