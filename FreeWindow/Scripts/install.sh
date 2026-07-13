#!/bin/bash
# install.sh — Install FreeWindow to /Applications.
# Installs bundled Ice only when /Applications/Ice.app is missing.
# Usage: ./Scripts/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${ROOT}/build/FreeWindow.app"
EMBEDDED_ICE="${APP}/Contents/Resources/Embedded/Ice.app"
ICE_DEST="/Applications/Ice.app"

if [[ ! -d "$APP" ]]; then
    echo "❌ ${APP} not found. Run ./Scripts/build-dmg.sh first."
    exit 1
fi

echo "📦 Installing FreeWindow to /Applications..."
ditto "$APP" /Applications/FreeWindow.app

if [[ -d "$ICE_DEST" ]]; then
    echo "✅ Ice already installed — skipping (preserves permissions)"
    pgrep -x Ice >/dev/null 2>&1 || open -a "$ICE_DEST"
elif [[ -d "$EMBEDDED_ICE" ]]; then
    echo "📎 First-time Ice install..."
    ditto "$EMBEDDED_ICE" "$ICE_DEST"
    open -a "$ICE_DEST"
else
    echo "⚠️  No embedded Ice in build — menu bar manager not installed"
fi

echo "🔄 Restarting FreeWindow (so new build picks up permissions)..."
osascript -e 'tell application "FreeWindow" to quit' 2>/dev/null || true
for _ in {1..10}; do
    pgrep -x FreeWindow >/dev/null 2>&1 || break
    sleep 0.3
done
pkill -x FreeWindow 2>/dev/null || true
sleep 0.5

open -a /Applications/FreeWindow.app

echo "✅ Done."
