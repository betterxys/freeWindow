#!/usr/bin/env bash
# One-line, self-contained installer for the Mac Window Manager.
#
# Designed to be piped from curl:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/scripts/install-oneline.sh)"
#
# Steps (each one is idempotent and narrates itself in plain language):
#   1. Verify we're on macOS.
#   2. Ensure Xcode Command Line Tools (needed for git).
#   3. Ensure Homebrew.
#   4. Install Hammerspoon (cask) if missing.
#   5. Clone / update this repo under ~/Library/Application Support/mac-window-manager.
#   6. Symlink into ~/.hammerspoon (backing up any existing config).
#   7. Launch Hammerspoon, open the Accessibility settings pane.
#   8. Wait for user confirmation, then trigger a live reload.
#   9. Print a success banner and a "try this first" hint.
#
# Safety notes:
#   * We NEVER delete an existing ~/.hammerspoon; we rename it with a timestamp.
#   * Every network download is printed before it happens.
#   * If anything fails, an error is printed and the installer exits non-zero;
#     re-running is always safe.

set -euo pipefail

# ---- configuration ---------------------------------------------------
REPO_URL_DEFAULT="https://github.com/betterxys/freeWindow.git"
REPO_URL="${MAC_WM_REPO_URL:-$REPO_URL_DEFAULT}"
REPO_BRANCH="${MAC_WM_BRANCH:-main}"
INSTALL_ROOT="${MAC_WM_INSTALL_ROOT:-${HOME}/Library/Application Support/mac-window-manager}"
TARGET="${HOME}/.hammerspoon"
LOG_PREFIX="\033[1;35m[mac-window-manager]\033[0m"

# ---- pretty printers -------------------------------------------------
step() { printf "\n${LOG_PREFIX} \033[1m%s\033[0m\n" "$*"; }
info() { printf "${LOG_PREFIX} %s\n" "$*"; }
ok()   { printf "${LOG_PREFIX} \033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "${LOG_PREFIX} \033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "${LOG_PREFIX} \033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

# ---- detect macOS ----------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  die "This installer only runs on macOS. Detected: $(uname)."
fi

# ---- Xcode Command Line Tools ---------------------------------------
ensure_xcode_clt() {
  step "Checking Apple Command Line Tools (needed for git)…"
  if xcode-select -p >/dev/null 2>&1; then
    ok "Command Line Tools already installed."
    return
  fi
  info "Installing Command Line Tools. A macOS dialog will pop up — click 'Install' and wait for it to finish."
  xcode-select --install >/dev/null 2>&1 || true
  # Wait (up to ~10 minutes) for the install to complete.
  local waited=0
  until xcode-select -p >/dev/null 2>&1; do
    if (( waited >= 600 )); then
      die "Command Line Tools not installed after 10 minutes. Re-run this installer once they finish."
    fi
    sleep 5
    waited=$(( waited + 5 ))
    printf "."
  done
  echo
  ok "Command Line Tools installed."
}

# ---- Homebrew --------------------------------------------------------
ensure_brew() {
  step "Checking Homebrew…"
  if command -v brew >/dev/null 2>&1; then
    ok "Homebrew already installed ($(brew --version | head -1))."
    return
  fi
  info "Homebrew not found. Installing from https://brew.sh (this is the official one-liner)."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Ensure brew is on PATH for the rest of this script.
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  command -v brew >/dev/null || die "Homebrew install appears to have failed."
  ok "Homebrew ready."
}

# ---- Hammerspoon -----------------------------------------------------
ensure_hammerspoon() {
  step "Checking Hammerspoon…"
  if [[ -d "/Applications/Hammerspoon.app" ]]; then
    ok "Hammerspoon.app already installed."
    return
  fi
  info "Installing Hammerspoon via Homebrew cask…"
  brew install --cask hammerspoon
  ok "Hammerspoon installed."
}

# ---- Clone / update repo --------------------------------------------
sync_repo() {
  step "Syncing Mac Window Manager repo to \"$INSTALL_ROOT\"…"
  mkdir -p "$(dirname "$INSTALL_ROOT")"
  if [[ -d "$INSTALL_ROOT/.git" ]]; then
    info "Updating existing checkout."
    git -C "$INSTALL_ROOT" fetch --quiet origin "$REPO_BRANCH"
    git -C "$INSTALL_ROOT" checkout --quiet "$REPO_BRANCH"
    git -C "$INSTALL_ROOT" reset --quiet --hard "origin/$REPO_BRANCH"
  else
    info "Cloning fresh checkout."
    rm -rf "$INSTALL_ROOT"
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_ROOT"
  fi
  ok "Repo ready at $INSTALL_ROOT."
}

# ---- Link into ~/.hammerspoon ---------------------------------------
link_config() {
  step "Installing config into $TARGET…"
  if [[ -L "$TARGET" ]]; then
    info "Removing previous symlink."
    rm "$TARGET"
  elif [[ -d "$TARGET" ]]; then
    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    local backup="${TARGET}.backup-${ts}"
    info "Backing up existing $TARGET -> $backup"
    mv "$TARGET" "$backup"
  fi
  mkdir -p "$TARGET"
  ln -sf  "$INSTALL_ROOT/init.lua" "$TARGET/init.lua"
  ln -sfn "$INSTALL_ROOT/modules"  "$TARGET/modules"
  ln -sfn "$INSTALL_ROOT/spec"     "$TARGET/spec"
  if [[ ! -f "$TARGET/config.lua" ]]; then
    cp "$INSTALL_ROOT/config.example.lua" "$TARGET/config.lua"
    info "Created $TARGET/config.lua from template."
  fi
  mkdir -p "$TARGET/layouts"
  ok "Config installed."
}

# ---- Launch Hammerspoon + guide Accessibility permission -----------
guide_accessibility() {
  step "Launching Hammerspoon and opening the Accessibility settings pane…"
  open -g -a Hammerspoon || true
  sleep 2
  # Open System Settings directly on the right pane.
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" >/dev/null 2>&1 || true

  # Native dialog so the user cannot miss the instruction.
  osascript >/dev/null 2>&1 <<'APPLESCRIPT' || true
display dialog "One-time setup:

1. In the System Settings window that just opened, find 'Hammerspoon' in the list and turn its switch ON.
2. If Hammerspoon is not in the list yet, click the '+' button and pick /Applications/Hammerspoon.app.
3. Click 'OK' below once you've done that." buttons {"OK"} default button "OK" with title "Mac Window Manager – Permission Setup" with icon note
APPLESCRIPT
  ok "Permission step acknowledged."
}

# ---- Reload Hammerspoon ---------------------------------------------
reload_hammerspoon() {
  step "Reloading Hammerspoon to pick up the new config…"
  if command -v hs >/dev/null 2>&1; then
    hs -c "hs.reload()" >/dev/null 2>&1 || true
  fi
  osascript -e 'tell application "Hammerspoon" to reload' >/dev/null 2>&1 || true
  ok "Reload requested."
}

# ---- Verify --------------------------------------------------------
verify() {
  step "Verifying install…"
  if [[ ! -L "$TARGET/init.lua" ]]; then
    warn "$TARGET/init.lua is not a symlink — something odd happened."
  else
    ok "$TARGET/init.lua -> $(readlink "$TARGET/init.lua")"
  fi
  if pgrep -x Hammerspoon >/dev/null; then
    ok "Hammerspoon is running."
  else
    warn "Hammerspoon does not appear to be running. Open Hammerspoon.app from Spotlight."
  fi
  if command -v hs >/dev/null 2>&1; then
    local state
    state="$(hs -c 'hs.accessibilityState()' 2>/dev/null || echo '?')"
    case "$state" in
      true)  ok "Accessibility permission granted." ;;
      false) warn "Accessibility permission is OFF. Flip the Hammerspoon switch in System Settings → Privacy & Security → Accessibility." ;;
      *)     info "Could not query Accessibility state (open Hammerspoon → Preferences → Install Command Line Tool for a cleaner doctor)." ;;
    esac
  fi
}

# ---- Finish --------------------------------------------------------
finish() {
  step "All done."
  cat <<'BANNER'

===============================================================
  🎉  Mac Window Manager is installed.

  Try it right now:
     1. Click on any window to focus it.
     2. Press  ⌃⌥⌘ + L   →  it should snap to the right half.
     3. Press  ⌃⌥⌘ + 2   →  it should jump to your 2nd monitor.

  More shortcuts & customization:
     ~/.hammerspoon/config.lua     (edit your prefix, role_map, …)
     README.md in this repo        (full hotkey table)

  Health check any time:
     bash "~/Library/Application Support/mac-window-manager/scripts/doctor.sh"

  To uninstall cleanly:
     bash "~/Library/Application Support/mac-window-manager/scripts/uninstall.sh"
===============================================================
BANNER

  # Visual "done" dialog so piping output won't get missed.
  osascript >/dev/null 2>&1 <<'APPLESCRIPT' || true
display dialog "🎉  Mac Window Manager is installed and running.

Try it now:
  •  ⌃⌥⌘ + L  →  snaps the focused window to the right half
  •  ⌃⌥⌘ + 2  →  sends it to monitor #2
  •  ⌃⌥⌘ + S  →  saves your current layout

See the README for the full hotkey table." buttons {"Got it"} default button "Got it" with title "Mac Window Manager" with icon note
APPLESCRIPT
}

main() {
  step "Mac Window Manager one-line installer starting."
  ensure_xcode_clt
  ensure_brew
  ensure_hammerspoon
  sync_repo
  link_config
  guide_accessibility
  reload_hammerspoon
  verify
  finish
}

main "$@"
