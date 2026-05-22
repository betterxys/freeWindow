-- Hammerspoon entry point. Installed as ~/.hammerspoon/init.lua (via symlink
-- created by scripts/install.sh).
--
-- Responsibilities:
--   1. Load the local config (if any).
--   2. Build the hotkey table from modules/hotkeys.lua and wire each entry
--      through modules/driver.lua so it drives the focused window.
--   3. Set up a screen-watcher that rebuilds the bindings when displays are
--      plugged/unplugged (so `send_to_screen_3` keeps pointing at the right
--      physical display even after a hardware change).
--   4. Install global Cmd-backed commands for save/restore layout.

local hotkeys_mod  = require("modules.hotkeys")
local driver       = require("modules.driver")
local cheatsheet   = require("modules.cheatsheet")

-- Enable hs CLI (hs -c '...') for doctor.sh and debugging.
require("hs.ipc")

local M = {}

-- ── Lightweight toast: small, brief, Esc to dismiss ─────────────────────────
local toast_style = {
  strokeWidth  = 0,
  strokeColor  = { white = 0, alpha = 0 },
  fillColor    = { white = 0, alpha = 0.6 },
  textColor    = { white = 1, alpha = 0.9 },
  textFont     = ".AppleSystemUIFont",
  textSize     = 14,
  radius       = 6,
  atScreenEdge = 0,
  fadeInDuration  = 0.1,
  fadeOutDuration = 0.15,
  padding         = { x = 14, y = 6 },
}

local TOAST_DURATION = 0.75  -- seconds

local function toast(msg)
  hs.alert.closeAll(0)
  hs.alert.show(msg, toast_style, TOAST_DURATION)
end

-- Load a user-local override if present. Never checked into git.
local ok, user_config = pcall(require, "config")
if not ok then user_config = {} end

M.config = {
  hyper       = user_config.hyper       or hotkeys_mod.DEFAULT_HYPER,
  hyper_shift = user_config.hyper_shift or hotkeys_mod.DEFAULT_HYPER_SHIFT,
  role_map    = user_config.role_map    or {},
  grid        = user_config.grid        or { cols = 12, rows = 8 },
  layouts_dir = user_config.layouts_dir or (os.getenv("HOME") .. "/.hammerspoon/layouts"),
}

-- Ensure the layouts dir exists (best-effort; ignore failures).
if hs.execute then
  hs.execute("mkdir -p '" .. M.config.layouts_dir:gsub("'", "'\\''") .. "'")
end

local active_bindings = {}

local function clear_bindings()
  for _, b in ipairs(active_bindings) do
    if b.handle and b.handle.delete then b.handle:delete() end
  end
  active_bindings = {}
end

local function install_bindings()
  clear_bindings()
  local bindings = hotkeys_mod.build(M.config.hyper, M.config.hyper_shift)

  local conflicts = hotkeys_mod.detect_conflicts(bindings)
  if #conflicts > 0 then
    local msgs = {}
    for _, c in ipairs(conflicts) do
      msgs[#msgs+1] = table.concat(c.mods, "+") .. "+" .. c.key ..
        " -> " .. table.concat(c.names, ", ")
    end
    toast("Hotkey conflicts:\n" .. table.concat(msgs, "\n"))
  end

  for _, b in ipairs(bindings) do
    local cb = driver.bind(b.action, {
      role_map = M.config.role_map,
      grid = M.config.grid,
    })
    local handle = hs.hotkey.bind(b.mods, b.key, b.name, cb)
    active_bindings[#active_bindings+1] = { handle = handle, name = b.name }
  end

  -- Save/restore layout: hyper+S / hyper+R
  active_bindings[#active_bindings+1] = { handle = hs.hotkey.bind(M.config.hyper, "s", "save_layout", function()
    local path = M.config.layouts_dir .. "/default.lua"
    driver.save_layout(path)
    toast("Saved layout -> " .. path)
  end), name = "save_layout" }

  active_bindings[#active_bindings+1] = { handle = hs.hotkey.bind(M.config.hyper, "r", "restore_layout", function()
    local path = M.config.layouts_dir .. "/default.lua"
    local ok_r, plan_or_err = pcall(driver.restore_layout, path)
    if not ok_r then
      toast("Restore failed: " .. tostring(plan_or_err))
    else
      toast(string.format("Restored %d windows (%d unresolved)",
        #plan_or_err.commands, #plan_or_err.unresolved))
    end
  end), name = "restore_layout" }

  -- Cheatsheet: hyper + /  (toggle floating hotkey reference panel)
  local cheatsheet_bindings = {}
  for _, b in ipairs(bindings) do
    cheatsheet_bindings[#cheatsheet_bindings+1] = b
  end
  cheatsheet_bindings[#cheatsheet_bindings+1] = {
    mods = M.config.hyper, key = "s", name = "save_layout",
  }
  cheatsheet_bindings[#cheatsheet_bindings+1] = {
    mods = M.config.hyper, key = "r", name = "restore_layout",
  }
  cheatsheet_bindings[#cheatsheet_bindings+1] = {
    mods = M.config.hyper, key = "/", name = "cheatsheet",
  }
  active_bindings[#active_bindings+1] = { handle = hs.hotkey.bind(M.config.hyper, "/", "cheatsheet", function()
    cheatsheet.toggle(cheatsheet_bindings, M.config.hyper)
  end), name = "cheatsheet" }
end

install_bindings()

-- Rewire on screen changes.
M.screen_watcher = hs.screen.watcher.new(function()
  install_bindings()
  -- hs.alert.show("Screen layout changed – bindings reinstalled")
end)
M.screen_watcher:start()

toast("Window manager loaded (" .. #active_bindings .. " hotkeys)")

return M
