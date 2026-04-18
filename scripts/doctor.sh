#!/usr/bin/env bash
# Quick health-check for the window-manager install on macOS.
#
# Usage: scripts/doctor.sh
#
# Exits non-zero and prints a summary if anything critical is wrong. Warnings
# do not fail the check but are printed in yellow.

set -uo pipefail

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass()  { printf "\033[1;32m✓\033[0m %s\n" "$*"; ((PASS_COUNT++)) || true; }
warn()  { printf "\033[1;33m!\033[0m %s\n" "$*"; ((WARN_COUNT++)) || true; }
fail()  { printf "\033[1;31m✗\033[0m %s\n" "$*"; ((FAIL_COUNT++)) || true; }

if [[ "$(uname)" != "Darwin" ]]; then
  warn "Not running on macOS ($(uname)). Most checks will be skipped."
  echo
fi

check_hammerspoon_installed() {
  if [[ -d "/Applications/Hammerspoon.app" ]]; then
    pass "Hammerspoon.app is installed in /Applications"
  else
    fail "Hammerspoon.app not found. Run scripts/install.sh or 'brew install --cask hammerspoon'."
  fi
}

check_hammerspoon_running() {
  if pgrep -x Hammerspoon >/dev/null; then
    pass "Hammerspoon is running"
  else
    warn "Hammerspoon is not running. Open Hammerspoon.app to start it."
  fi
}

check_config_linked() {
  local init="${HOME}/.hammerspoon/init.lua"
  if [[ -L "$init" ]]; then
    local target; target="$(readlink "$init")"
    pass "~/.hammerspoon/init.lua -> $target"
  elif [[ -f "$init" ]]; then
    warn "~/.hammerspoon/init.lua exists but is not a symlink. scripts/install.sh backs this up and links ours."
  else
    fail "~/.hammerspoon/init.lua missing. Run scripts/install.sh."
  fi
}

check_accessibility() {
  # We can't reliably read TCC.db, but we can check a Hammerspoon CLI signal.
  if command -v hs >/dev/null 2>&1; then
    local res
    res="$(hs -c 'hs.accessibilityState()' 2>/dev/null || echo 'error')"
    if [[ "$res" == "true" ]]; then
      pass "Accessibility permission granted (hs.accessibilityState = true)"
    elif [[ "$res" == "false" ]]; then
      fail "Accessibility permission NOT granted. System Settings → Privacy & Security → Accessibility → enable Hammerspoon."
    else
      warn "Could not query accessibility state. Enable Hammerspoon CLI via the Hammerspoon menu (Install Command Line Tool)."
    fi
  else
    warn "Hammerspoon CLI ('hs') not found. Open Hammerspoon → Preferences → Install Command Line Tool."
  fi
}

check_screens() {
  if ! command -v hs >/dev/null 2>&1; then
    warn "Skipping screen enumeration (hs CLI missing)."
    return
  fi
  local count
  count="$(hs -c '#hs.screen.allScreens()' 2>/dev/null || echo 0)"
  if [[ "$count" =~ ^[0-9]+$ ]] && [[ "$count" -gt 0 ]]; then
    pass "Detected $count screen(s)"
    hs -c 'for i,s in ipairs(hs.screen.allScreens()) do print(string.format("   [%d] %s  %dx%d @ (%d,%d)", i, s:name(), s:frame().w, s:frame().h, s:frame().x, s:frame().y)) end' 2>/dev/null || true
  else
    warn "Could not enumerate screens."
  fi
}

check_hotkeys_conflict_with_macos() {
  # A very short list of well-known macOS / common-app shortcuts that use the
  # same prefix (ctrl+alt+cmd). If the user has any of these remapped they
  # may need to pick a different hyper.
  cat <<'EOF'
ℹ  Our default prefix is ⌃⌥⌘ (hyper). Known apps that sometimes grab this:
     - Raycast / Alfred hotkeys (check their Preferences).
     - BetterTouchTool, Karabiner, Rectangle (make sure Rectangle's overlap
       options are off or set to the hyper+shift layer).
     - Microsoft apps occasionally.
   If a hotkey "just doesn't fire", open Hammerspoon Console and look for
   "Warning: hotkey already bound" messages, or change `hyper` in ~/.hammerspoon/config.lua.
EOF
}

check_bindings_loaded() {
  if ! command -v hs >/dev/null 2>&1; then return; fi
  local n
  n="$(hs -c 'return require("init") and "ok"' 2>/dev/null || echo "fail")"
  if [[ "$n" == *ok* ]]; then
    pass "init.lua loads without error in the running Hammerspoon"
  else
    warn "Could not confirm init.lua is loaded. Open Hammerspoon Console for details."
  fi
}

echo "=== Mac Window Manager Doctor ==="
echo
check_hammerspoon_installed
check_hammerspoon_running
check_config_linked
check_accessibility
check_screens
check_bindings_loaded
echo
check_hotkeys_conflict_with_macos
echo
echo "Summary: $PASS_COUNT passed, $WARN_COUNT warnings, $FAIL_COUNT failed."

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
