#!/usr/bin/env bash
# Install this repo as the active Hammerspoon config on macOS.
#
# Strategy:
#   * Ensure Hammerspoon is installed (via Homebrew cask).
#   * Back up any existing ~/.hammerspoon directory to
#     ~/.hammerspoon.backup-<timestamp>.
#   * Symlink this repo's init.lua, modules/, config.example.lua to
#     ~/.hammerspoon/ (so git pulls take effect immediately).
#   * Leave any user-created ~/.hammerspoon/config.lua in place.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${HOME}/.hammerspoon"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This installer only runs on macOS. Detected: $(uname)" >&2
  exit 1
fi

info()  { printf "\033[1;34m•\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m!\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; }

install_hammerspoon() {
  if [[ -d "/Applications/Hammerspoon.app" ]]; then
    ok "Hammerspoon.app already installed"
    return
  fi
  if command -v brew >/dev/null 2>&1; then
    info "Installing Hammerspoon via Homebrew cask..."
    brew install --cask hammerspoon
    ok "Hammerspoon installed"
  else
    error "Homebrew not found. Install from https://brew.sh, then re-run this script."
    error "Alternatively, download Hammerspoon from https://www.hammerspoon.org and put it in /Applications."
    exit 1
  fi
}

backup_existing() {
  if [[ -L "$TARGET" ]]; then
    info "Existing $TARGET is a symlink; removing it."
    rm "$TARGET"
    return
  fi
  if [[ -d "$TARGET" ]]; then
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local backup="${TARGET}.backup-${ts}"
    info "Backing up existing $TARGET -> $backup"
    mv "$TARGET" "$backup"
    ok "Backup done"
  fi
}

link_config() {
  mkdir -p "$TARGET"
  info "Linking config files into $TARGET"
  # init.lua is linked so `git pull` propagates immediately.
  ln -sf "${REPO_ROOT}/init.lua"    "${TARGET}/init.lua"
  ln -sfn "${REPO_ROOT}/modules"    "${TARGET}/modules"
  ln -sfn "${REPO_ROOT}/spec"       "${TARGET}/spec"
  # Example config is copied (not linked) so user edits don't touch the repo.
  if [[ ! -f "${TARGET}/config.lua" ]]; then
    cp "${REPO_ROOT}/config.example.lua" "${TARGET}/config.lua"
    info "Created ${TARGET}/config.lua from template (edit to customize)"
  else
    info "Keeping existing ${TARGET}/config.lua"
  fi
  mkdir -p "${TARGET}/layouts"
  ok "Files linked"
}

reload_hammerspoon() {
  info "Asking Hammerspoon to reload its config..."
  # The --check flag returns 0 when Hammerspoon is running.
  if pgrep -x Hammerspoon >/dev/null; then
    if command -v hs >/dev/null 2>&1; then
      hs -c "hs.reload()" >/dev/null 2>&1 || true
    fi
    osascript -e 'tell application "Hammerspoon" to reload' >/dev/null 2>&1 || true
    ok "Reload requested"
  else
    info "Hammerspoon is not running. Launching it now."
    open -a Hammerspoon || true
  fi
}

install_hammerspoon
backup_existing
link_config
reload_hammerspoon

cat <<'EOF'

================================================================
Install complete.

Next steps on your Mac:
  1. Open System Settings → Privacy & Security → Accessibility
     and enable "Hammerspoon".
  2. (Optional) Edit ~/.hammerspoon/config.lua to set your role_map
     (e.g. which display is "left" / "main" / "right").
  3. Run scripts/doctor.sh to verify your setup.
  4. Try a hotkey: focus any window, press ⌃⌥⌘+L — it should snap
     to the right half of the current screen.

To update after a git pull:
  * Most changes take effect automatically (init.lua is symlinked).
  * Click the Hammerspoon menu bar icon → "Reload Config" to force reload.
================================================================
EOF
