#!/usr/bin/env bash
# Double-click-to-install entry point for the Mac Window Manager.
#
# How this works:
#   * macOS treats any *.command file as executable in Finder: double-clicking
#     it opens Terminal.app and runs the script.
#   * We just delegate to install-oneline.sh located next to this file
#     (works if the user cloned the repo and opens it in Finder).
#   * If the sibling script is missing (e.g. user downloaded only this file),
#     we fall back to fetching the latest installer over the network.
#
# Users who are allergic to the terminal: this is the entry point for you.

set -u

here="$(cd "$(dirname "$0")" && pwd)"
sibling="${here}/install-oneline.sh"

ONELINE_URL="${MAC_WM_ONELINE_URL:-https://raw.githubusercontent.com/betterxys/freeWindow/main/scripts/install-oneline.sh}"

banner() {
  cat <<'EOF'

============================================================
   Mac Window Manager – one-click installer
============================================================

This will:
  1. Install the Apple Command Line Tools (first time only)
  2. Install Homebrew (first time only)
  3. Install Hammerspoon
  4. Put the Mac Window Manager config into ~/.hammerspoon
  5. Open the Accessibility permission screen for you

You can close this window when it says "All done."

EOF
}

banner

if [[ -x "$sibling" ]]; then
  echo "→ Running local installer: $sibling"
  exec "$sibling"
elif [[ -f "$sibling" ]]; then
  echo "→ Running local installer (via bash): $sibling"
  exec /bin/bash "$sibling"
else
  echo "→ Fetching the latest installer from GitHub…"
  exec /bin/bash -c "$(curl -fsSL "$ONELINE_URL")"
fi
