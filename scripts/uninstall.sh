#!/usr/bin/env bash
# One-click uninstaller. Designed to be safe and chatty: by default it only
# removes the symlinks we created and restores the most recent backup of
# ~/.hammerspoon (if there is one). Pass --purge to also remove the repo
# checkout and the Hammerspoon.app (Homebrew cask).

set -euo pipefail

TARGET="${HOME}/.hammerspoon"
INSTALL_ROOT="${MAC_WM_INSTALL_ROOT:-${HOME}/Library/Application Support/mac-window-manager}"

PURGE=0
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    -h|--help)
      cat <<EOF
Usage: uninstall.sh [--purge]

  (no args)  Revert ~/.hammerspoon to its most recent backup (or empty it).
  --purge    Also remove the repo checkout and 'brew uninstall --cask hammerspoon'.
EOF
      exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

info() { printf "\033[1;34m•\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }

if [[ "$(uname)" != "Darwin" ]]; then
  warn "Not macOS. Most steps will be skipped (safe to run for smoke testing)."
fi

revert_hammerspoon_dir() {
  if [[ -L "$TARGET" ]]; then
    info "Removing symlink $TARGET"
    rm "$TARGET"
  elif [[ -d "$TARGET" ]]; then
    # Remove only *our* symlinks from inside the dir; leave any user files.
    for f in init.lua modules spec; do
      if [[ -L "$TARGET/$f" ]]; then
        info "Removing $TARGET/$f"
        rm "$TARGET/$f"
      fi
    done
    # Preserve user-edited config.lua by renaming it to keep the option open.
    if [[ -f "$TARGET/config.lua" ]]; then
      local ts; ts="$(date +%Y%m%d-%H%M%S)"
      info "Keeping your config.lua as $TARGET/config.lua.saved-${ts}"
      mv "$TARGET/config.lua" "$TARGET/config.lua.saved-${ts}"
    fi
  fi

  # Restore the newest backup, if any. Using find+stat instead of `ls -dt` to
  # stay robust against unusual filenames (shellcheck SC2012).
  local latest=""
  if compgen -G "${HOME}/.hammerspoon.backup-*" >/dev/null; then
    latest="$(find "${HOME}" -maxdepth 1 -name '.hammerspoon.backup-*' -print0 2>/dev/null \
      | xargs -0 -I{} stat -f '%m %N' "{}" 2>/dev/null \
      | sort -rn | head -1 | cut -d' ' -f2-)"
    if [[ -z "$latest" ]]; then
      # Fallback for GNU stat (Linux) when smoke-testing.
      latest="$(find "${HOME}" -maxdepth 1 -name '.hammerspoon.backup-*' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -1 | cut -d' ' -f2-)"
    fi
  fi
  if [[ -n "$latest" ]]; then
    if [[ -e "$TARGET" ]]; then
      info "Merging restored backup into existing $TARGET (leaving your kept files alone)."
      cp -Rn "$latest"/* "$TARGET/" 2>/dev/null || true
    else
      info "Restoring backup $latest -> $TARGET"
      mv "$latest" "$TARGET"
    fi
    ok "Previous Hammerspoon config restored."
  else
    info "No backup found at ~/.hammerspoon.backup-*; leaving $TARGET as-is."
  fi
}

purge_repo_checkout() {
  if [[ -d "$INSTALL_ROOT" ]]; then
    info "Removing repo checkout: $INSTALL_ROOT"
    rm -rf "$INSTALL_ROOT"
    ok "Repo removed."
  fi
}

purge_hammerspoon_app() {
  if command -v brew >/dev/null 2>&1; then
    if brew list --cask hammerspoon >/dev/null 2>&1; then
      info "Uninstalling Hammerspoon cask via Homebrew."
      brew uninstall --cask hammerspoon || true
      ok "Hammerspoon uninstalled."
    else
      info "Hammerspoon cask not installed via brew; leaving /Applications/Hammerspoon.app alone."
    fi
  fi
}

revert_hammerspoon_dir

if (( PURGE )); then
  purge_repo_checkout
  purge_hammerspoon_app
  warn "Accessibility permission for Hammerspoon may still be listed in System Settings. Remove it by clicking the '-' in Privacy & Security → Accessibility if you want a fully clean slate."
fi

echo
ok "Done."
