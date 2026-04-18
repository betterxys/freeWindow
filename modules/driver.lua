-- Thin adapter between the pure-logic modules and the live Hammerspoon
-- runtime. Everything that actually pokes at windows, screens, or disk lives
-- here, so it is also the single place we have to stub out under tests.
--
-- At require-time we DO NOT touch `hs.*`, so this module is still load-safe
-- on Linux. Only the functions, when called, dereference `hs`.

local geometry = require("modules.geometry")
local screens = require("modules.screens")
local layouts = require("modules.layouts")

local M = {}

-- Optional injection point for tests. When set, used instead of the global
-- Hammerspoon namespace. Production code leaves this nil.
M._hs = nil

local function api()
  return M._hs or _G.hs
end

--- Snapshot the screen layout into a form `screens.resolver` understands.
function M.snapshot_screens()
  local hs = api()
  local all = hs.screen.allScreens()
  local out = {}
  for i, s in ipairs(all) do
    out[i] = { id = s:id(), name = s:name(), frame = s:frame() }
  end
  return out
end

--- Build an action context for the currently focused window.
function M.build_ctx(opts)
  opts = opts or {}
  local hs = api()
  local screens_raw = M.snapshot_screens()
  local resolver = screens.resolver(screens_raw, opts.role_map or {})
  local ordered = resolver.ordered

  local win = hs.window.focusedWindow()
  if not win then return nil end
  local win_frame = win:frame()

  local idx = geometry.screen_for_rect(ordered, win_frame)
    or resolver:index_for_id(win:screen():id())
    or 1

  return {
    window = { id = win:id(), frame = win_frame, _handle = win },
    screen_index = idx,
    screens = ordered,
    resolver = resolver,
    grid = opts.grid or { cols = 12, rows = 8 },
  }, win
end

--- Apply a desired frame to `win`. Uses `setFrame` with animation disabled
-- to match expectations in the test snapshots.
function M.apply_frame(win, frame)
  local hs = api()
  local prev = hs.window.animationDuration
  hs.window.animationDuration = 0
  win:setFrame(frame)
  hs.window.animationDuration = prev
end

--- Wrap a pure action so it can be bound directly to a Hammerspoon hotkey.
-- The wrapper builds a context, runs the action, and applies the frame.
function M.bind(action, opts)
  return function()
    local ctx, win = M.build_ctx(opts)
    if not ctx then return end
    local result = action(ctx)
    if type(result) == "table" and result.x ~= nil then
      M.apply_frame(win, result)
    end
  end
end

--- Capture the current world for `layouts`.
function M.capture_world()
  local hs = api()
  local screens_raw = M.snapshot_screens()
  local resolver = screens.resolver(screens_raw, {})
  local windows = {}
  local visible = hs.window.visibleWindows and hs.window.visibleWindows() or {}
  for _, w in ipairs(visible) do
    if w:isStandard() and not w:isMinimized() then
      local f = w:frame()
      local app = w:application() and w:application():name() or nil
      local scr_idx = geometry.screen_for_rect(resolver.ordered, f)
        or resolver:index_for_id(w:screen():id())
        or 1
      windows[#windows + 1] = {
        id = w:id(),
        title = w:title(),
        app = app,
        screen_index = scr_idx,
        frame = f,
      }
    end
  end
  return { screens = resolver.ordered, windows = windows }
end

function M.save_layout(path)
  local snap = layouts.capture(M.capture_world())
  local f, err = io.open(path, "w")
  if not f then error("cannot write " .. path .. ": " .. tostring(err)) end
  f:write(layouts.serialize(snap))
  f:close()
  return snap
end

function M.restore_layout(path)
  local hs = api()
  local f, err = io.open(path, "r")
  if not f then error("cannot read " .. path .. ": " .. tostring(err)) end
  local snap = layouts.deserialize(f:read("*a"))
  f:close()

  local plan = layouts.plan_restore(snap, M.capture_world())
  -- Build id->window map
  local by_id = {}
  for _, w in ipairs(hs.window.visibleWindows and hs.window.visibleWindows() or {}) do
    by_id[w:id()] = w
  end
  for _, cmd in ipairs(plan.commands) do
    local win = by_id[cmd.window_id]
    if win then M.apply_frame(win, cmd.frame) end
  end
  return plan
end

return M
