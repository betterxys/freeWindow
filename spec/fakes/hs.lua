-- Linux-side stand-in for the Hammerspoon `hs` namespace.
--
-- We only fake the surface our own code touches. The fake records state so
-- tests can assert things like:
--   * which hotkeys got bound
--   * which setFrame calls were made, and in what order
--   * what screen watchers exist
--
-- Every test that loads this module should call `hs._reset()` in a
-- `before_each` to get a clean world. World population is done via
-- `hs._load_world({ screens = {...}, windows = {...}, focused = id })`.

local geometry = require("modules.geometry")

local M = {}

local state

local function reset_state()
  state = {
    screens = {},       -- list of { id, name, frame }
    windows = {},       -- id -> window table
    window_order = {},  -- ids, for visibleWindows()
    focused_id = nil,
    hotkeys = {},       -- list of active hotkeys
    screen_watchers = {},
    set_frame_log = {}, -- list of { window_id, frame }
    alerts = {},        -- list of alert messages
    executed = {},      -- list of shell commands requested via hs.execute
    animation_duration = 0.2,
  }
end

reset_state()

-- === Helpers exposed to tests =========================================

M._reset = reset_state
M._state = function() return state end
M._hotkeys = function() return state.hotkeys end
M._set_frame_log = function() return state.set_frame_log end
M._alerts = function() return state.alerts end

local function populate(world)
  state.screens = {}
  state.windows = {}
  state.window_order = {}
  for _, s in ipairs(world.screens or {}) do
    state.screens[#state.screens + 1] = {
      id = s.id, name = s.name, frame = { x = s.frame.x, y = s.frame.y, w = s.frame.w, h = s.frame.h },
    }
  end
  for _, w in ipairs(world.windows or {}) do
    state.windows[w.id] = {
      id = w.id,
      title = w.title or ("window " .. tostring(w.id)),
      app = w.app or "TestApp",
      standard = w.standard ~= false,
      minimized = w.minimized or false,
      frame = { x = w.frame.x, y = w.frame.y, w = w.frame.w, h = w.frame.h },
    }
    state.window_order[#state.window_order + 1] = w.id
  end
  state.focused_id = world.focused
end

--- Reset state and load a fresh world (bindings/alerts cleared).
function M._load_world(world)
  reset_state()
  populate(world)
end

--- Update screens/windows without clearing bindings or watchers. Used for
-- simulating screen unplug / replug mid-scenario.
function M._update_world(world)
  populate(world)
end

function M._focus(id)
  state.focused_id = id
end

function M._press(mods, key)
  local mods_norm = {}
  for _, m in ipairs(mods) do mods_norm[#mods_norm+1] = m:lower() end
  table.sort(mods_norm)
  local sig = table.concat(mods_norm, "+") .. "/" .. key:lower()
  for _, hk in ipairs(state.hotkeys) do
    local hk_mods = {}
    for _, m in ipairs(hk.mods) do hk_mods[#hk_mods+1] = m:lower() end
    table.sort(hk_mods)
    local hk_sig = table.concat(hk_mods, "+") .. "/" .. hk.key:lower()
    if hk_sig == sig then
      hk.callback()
      return true
    end
  end
  return false
end

--- Fire the registered screen watchers (e.g. simulating a monitor unplug).
function M._fire_screen_change()
  for _, cb in ipairs(state.screen_watchers) do cb() end
end

-- === hs.screen ========================================================

local Screen = {}
Screen.__index = Screen

function Screen:id() return self._id end
function Screen:name() return self._name end
function Screen:frame() return geometry.copy(self._frame) end
function Screen:fullFrame() return geometry.copy(self._frame) end

local function wrap_screen(raw)
  return setmetatable({ _id = raw.id, _name = raw.name, _frame = raw.frame }, Screen)
end

M.screen = {}

function M.screen.allScreens()
  local out = {}
  for i, s in ipairs(state.screens) do out[i] = wrap_screen(s) end
  return out
end

function M.screen.mainScreen()
  local s = state.screens[1]
  return s and wrap_screen(s) or nil
end

M.screen.watcher = {}
function M.screen.watcher.new(cb)
  local w = { _cb = cb, _started = false }
  function w:start() self._started = true; state.screen_watchers[#state.screen_watchers+1] = self._cb; return self end
  function w:stop() self._started = false; return self end
  return w
end

-- === hs.window ========================================================

local Window = {}
Window.__index = Window

function Window:id() return self._raw.id end
function Window:title() return self._raw.title end
function Window:application() return { name = function() return self._raw.app end } end
function Window:isStandard() return self._raw.standard end
function Window:isMinimized() return self._raw.minimized end
function Window:frame() return geometry.copy(self._raw.frame) end

function Window:setFrame(f)
  self._raw.frame = { x = f.x, y = f.y, w = f.w, h = f.h }
  state.set_frame_log[#state.set_frame_log + 1] = {
    window_id = self._raw.id,
    frame = geometry.copy(self._raw.frame),
  }
end

function Window:screen()
  local idx = geometry.screen_for_rect(
    (function()
      local out = {}
      for i, s in ipairs(state.screens) do out[i] = { frame = s.frame } end
      return out
    end)(),
    self._raw.frame
  ) or 1
  local s = state.screens[idx]
  return s and wrap_screen(s) or nil
end

local function wrap_window(raw)
  return setmetatable({ _raw = raw }, Window)
end

M.window = setmetatable({
  animationDuration = 0.2,
}, {})

function M.window.focusedWindow()
  local raw = state.windows[state.focused_id]
  return raw and wrap_window(raw) or nil
end

function M.window.visibleWindows()
  local out = {}
  for _, id in ipairs(state.window_order) do
    local raw = state.windows[id]
    if raw and not raw.minimized then out[#out+1] = wrap_window(raw) end
  end
  return out
end

-- === hs.hotkey ========================================================

M.hotkey = {}

function M.hotkey.bind(mods, key, name, callback)
  -- Hammerspoon allows bind(mods, key, callback) with no name too.
  if type(name) == "function" and callback == nil then
    callback = name
    name = nil
  end
  local hk = { mods = mods, key = key, name = name, callback = callback, enabled = true }
  function hk:delete()
    for i, h in ipairs(state.hotkeys) do
      if h == self then table.remove(state.hotkeys, i); return end
    end
  end
  function hk:disable() self.enabled = false end
  function hk:enable() self.enabled = true end
  state.hotkeys[#state.hotkeys+1] = hk
  return hk
end

-- === hs.alert =========================================================

M.alert = {}
function M.alert.show(msg)
  state.alerts[#state.alerts+1] = tostring(msg)
end

-- === hs.execute =======================================================

function M.execute(cmd)
  state.executed[#state.executed+1] = cmd
  return "", true, "exit", 0
end

return M
