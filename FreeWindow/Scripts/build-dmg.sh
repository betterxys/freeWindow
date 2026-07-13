#!/bin/bash
# build-dmg.sh — Build FreeWindow.app and package as DMG.
# Bundles Ice for automatic menu-bar management on first launch.
# Usage: ./Scripts/build-dmg.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

APP_NAME="FreeWindow"
INFO_PLIST="${ROOT_DIR}/${APP_NAME}/Resources/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}")"
ICE_VERSION="0.11.12"
ICE_URL="https://github.com/jordanbaird/Ice/releases/download/${ICE_VERSION}/Ice.zip"
BUILD_DIR="${ROOT_DIR}/build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
EMBEDDED_DIR="${APP_DIR}/Contents/Resources/Embedded"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
STAGING="${BUILD_DIR}/dmg-staging"

echo "🔨 Building ${APP_NAME}..."

# --- Step 1: Build the Swift executable ---
swift build -c release --package-path "$(pwd)"

# --- Step 2: Fetch Ice (menu bar manager, bundled for one-step install) ---
ICE_APP="${BUILD_DIR}/Ice.app"
if [[ ! -d "${ICE_APP}/Contents/MacOS/Ice" ]]; then
    echo "📥 Downloading Ice ${ICE_VERSION}..."
    ICE_ZIP="${BUILD_DIR}/Ice.zip"
    if curl -fsSL "${ICE_URL}" -o "${ICE_ZIP}"; then
        rm -rf "${ICE_APP}"
        unzip -qo "${ICE_ZIP}" -d "${BUILD_DIR}"
    elif [[ -d "/Applications/Ice.app" ]]; then
        echo "⚠️  Download failed — using /Applications/Ice.app for embedding"
        rm -rf "${ICE_APP}"
        ditto "/Applications/Ice.app" "${ICE_APP}"
    else
        echo "⚠️  Could not download Ice and no local copy found — building without embedded Ice"
        ICE_APP=""
    fi
fi

# --- Step 3: Create .app bundle ---
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "$(swift build -c release --package-path "$(pwd)" --show-bin-path)/${APP_NAME}" \
   "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cp "${APP_NAME}/Resources/Info.plist" "${APP_DIR}/Contents/"

if [[ -f "Packaging/AppIcon.icns" ]]; then
    cp "Packaging/AppIcon.icns" "${APP_DIR}/Contents/Resources/"
elif [[ -f "Packaging/FreeWindow-icon.svg" ]]; then
    echo "🎨 Generating AppIcon.icns from SVG..."
    ICON_SOURCE="${BUILD_DIR}/AppIcon-source.png"
    ICONSET="${BUILD_DIR}/AppIcon.iconset"
    rm -rf "${ICONSET}" && mkdir -p "${ICONSET}"
    sips -s format png "Packaging/FreeWindow-icon.svg" --out "${ICON_SOURCE}" >/dev/null
    for spec in \
        "16 icon_16x16.png" "32 icon_16x16@2x.png" \
        "32 icon_32x32.png" "64 icon_32x32@2x.png" \
        "128 icon_128x128.png" "256 icon_128x128@2x.png" \
        "256 icon_256x256.png" "512 icon_256x256@2x.png" \
        "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
        size="${spec%% *}"
        name="${spec#* }"
        sips -z "${size}" "${size}" "${ICON_SOURCE}" \
            --out "${ICONSET}/${name}" >/dev/null
    done
    iconutil -c icns "${ICONSET}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

if [[ -n "${ICE_APP}" && -d "${ICE_APP}" ]]; then
    echo "📎 Embedding Ice into FreeWindow.app..."
    mkdir -p "${EMBEDDED_DIR}"
    ditto "${ICE_APP}" "${EMBEDDED_DIR}/Ice.app"
    if [[ -f "Packaging/THIRD_PARTY_NOTICES.md" ]]; then
        cp "Packaging/THIRD_PARTY_NOTICES.md" "${APP_DIR}/Contents/Resources/"
    fi
    # Keep Ice's upstream Developer ID signature — ad-hoc re-signing breaks
    # macOS Accessibility / TCC binding and causes Ice's permission banner.
fi

echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Sign FreeWindow with a stable Apple or trusted local certificate when
# available (keeps Accessibility across rebuilds). Ad-hoc (--sign -) changes
# CDHash every build and forces the user to re-authorize Accessibility.
# shellcheck source=Scripts/resolve-sign-identity.sh
source "$(dirname "$0")/resolve-sign-identity.sh"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    echo "🔏 Signing with: ${SIGN_IDENTITY}"
    codesign --force --sign "${SIGN_IDENTITY}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
    codesign --force --sign "${SIGN_IDENTITY}" "${APP_DIR}"
else
    echo "⚠️  No stable signing identity — using ad-hoc signature."
    echo "    Accessibility will reset after each rebuild. Run ./Scripts/setup-signing.sh"
    codesign --force --sign - "${APP_DIR}/Contents/MacOS/${APP_NAME}"
    codesign --force --sign - "${APP_DIR}"
fi

echo "✅ Built ${APP_DIR}"

# --- Step 4: Create DMG ---
echo "📦 Creating DMG..."
rm -rf "${STAGING}" && mkdir -p "${STAGING}"
cp -R "${APP_DIR}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"
rm -f "${BUILD_DIR}/${DMG_NAME}"

if command -v create-dmg &>/dev/null; then
    if ! create-dmg \
        --volname "${APP_NAME}" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 150 200 \
        --icon "Applications" 450 200 \
        --hide-extension "${APP_NAME}.app" \
        "${BUILD_DIR}/${DMG_NAME}" \
        "${STAGING}/"; then
        echo "⚠️  create-dmg failed; falling back to hdiutil"
        rm -f "${BUILD_DIR}/${DMG_NAME}"
        hdiutil create -volname "${APP_NAME}" \
            -srcfolder "${STAGING}" \
            -ov -format UDZO \
            "${BUILD_DIR}/${DMG_NAME}"
    fi
else
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${STAGING}" \
        -ov -format UDZO \
        "${BUILD_DIR}/${DMG_NAME}"
fi

rm -rf "${STAGING}"
echo "✅ DMG created: ${BUILD_DIR}/${DMG_NAME}"
echo ""
echo "To install: open the DMG and drag FreeWindow to Applications."
echo "First launch installs Ice automatically and starts both apps."
echo "Grant Accessibility to FreeWindow and Ice when macOS prompts."
