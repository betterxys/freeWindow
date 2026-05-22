#!/bin/bash
# build-dmg.sh — Build FreeWindow.app and package as DMG.
# Usage: ./Scripts/build-dmg.sh
set -euo pipefail

APP_NAME="FreeWindow"
VERSION="1.0.0"
BUILD_DIR="$(pwd)/build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
STAGING="${BUILD_DIR}/dmg-staging"

echo "🔨 Building ${APP_NAME}..."

# --- Step 1: Build the Swift executable ---
swift build -c release --package-path "$(pwd)"

# --- Step 2: Create .app bundle ---
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable
cp "$(swift build -c release --package-path "$(pwd)" --show-bin-path)/${APP_NAME}" \
   "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "${APP_NAME}/Resources/Info.plist" "${APP_DIR}/Contents/"

# Copy icon if it exists
if [ -f "Packaging/AppIcon.icns" ]; then
    cp "Packaging/AppIcon.icns" "${APP_DIR}/Contents/Resources/"
fi

# Create PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Ad-hoc code sign (prevents macOS from re-prompting accessibility on every update)
codesign --force --deep --sign - "${APP_DIR}"

echo "✅ Built ${APP_DIR}"

# --- Step 3: Create DMG ---
echo "📦 Creating DMG..."
rm -rf "${STAGING}" && mkdir -p "${STAGING}"
cp -R "${APP_DIR}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

# Check if create-dmg is available
if command -v create-dmg &>/dev/null; then
    create-dmg \
        --volname "${APP_NAME}" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 150 200 \
        --icon "Applications" 450 200 \
        --hide-extension "${APP_NAME}.app" \
        "${BUILD_DIR}/${DMG_NAME}" \
        "${STAGING}/" || true
else
    # Fallback: use hdiutil directly
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${STAGING}" \
        -ov -format UDZO \
        "${BUILD_DIR}/${DMG_NAME}"
fi

rm -rf "${STAGING}"
echo "✅ DMG created: ${BUILD_DIR}/${DMG_NAME}"
echo ""
echo "To install: open the DMG and drag FreeWindow to Applications."
echo "First launch: macOS will ask for Accessibility permission."
