-- Scenario replay tests.
--
-- Each scenario drives a sequence of hotkeys through init.lua under the fake
-- runtime and asserts against a golden snapshot of the setFrame log. If the
-- recorded behavior changes, the golden JSON (plain Lua table) needs to be
-- updated explicitly — which is exactly the signal we want.

local layouts = require("modules.layouts")

local function fresh_hs()
  for name in pairs(package.loaded) do
    if name == "init" or name:match("^modules%.") or name == "hs" or name == "config" then
      package.loaded[name] = nil
    end
  end
  _G.hs = require("hs")
  _G.hs._reset()
  return _G.hs
end

local function load_scenario(hs, world)
  hs._load_world(world)
  require("init")
end

local function run_script(hs, script)
  for _, step in ipairs(script) do
    if step.kind == "press" then
      assert.is_true(hs._press(step.mods, step.key),
        "unbound hotkey: " .. table.concat(step.mods, "+") .. "+" .. step.key)
    elseif step.kind == "focus" then
      hs._focus(step.id)
    elseif step.kind == "screen_change" then
      hs._update_world(step.world)
      hs._fire_screen_change()
    end
  end
end

local function snapshot_moves(hs)
  return hs._set_frame_log()
end

local function format_golden(moves)
  return layouts.serialize(moves)
end

-- Write-and-read pattern: tests read the golden file; if missing, create it.
-- A new scenario can be bootstrapped by deleting the file and re-running.
local function golden(name, moves)
  local path = "spec/golden/" .. name .. ".lua"
  local f = io.open(path, "r")
  if not f then
    f = assert(io.open(path, "w"))
    f:write(format_golden(moves))
    f:close()
    error("created golden file " .. path .. "; re-run the tests")
  end
  local body = f:read("*a"); f:close()
  local chunk = assert(load(body, "=(" .. path .. ")", "t", {}))
  local expected = chunk()
  assert.are.same(expected, moves)
end

describe("scenarios: sequenced hotkeys produce stable output", function()
  it("three-monitor developer loop", function()
    local hs = fresh_hs()
    load_scenario(hs, {
      screens = FIXTURES.three_monitors(),
      windows = {
        { id = 1, title = "Editor",   app = "VSCode",   frame = { x = 0,    y = 50,  w = 1200, h = 800 } },
        { id = 2, title = "Terminal", app = "iTerm2",   frame = { x = 200,  y = 200, w = 800, h = 500 } },
        { id = 3, title = "Browser",  app = "Safari",   frame = { x = 1600, y = 100, w = 1400, h = 900 } },
      },
      focused = 1,
    })

    run_script(hs, {
      { kind = "press",  mods = { "ctrl","alt","cmd" }, key = "return" }, -- maximize editor on whatever screen
      { kind = "press",  mods = { "ctrl","alt","cmd" }, key = "3" },     -- send editor to 4K
      { kind = "press",  mods = { "ctrl","alt","cmd" }, key = "h" },     -- left half of 4K
      { kind = "focus",  id = 2 },
      { kind = "press",  mods = { "ctrl","alt","cmd" }, key = "3" },     -- terminal to 4K
      { kind = "press",  mods = { "ctrl","alt","cmd" }, key = "l" },     -- right half of 4K
      { kind = "focus",  id = 3 },
      { kind = "press",  mods = { "ctrl","alt","cmd" }, key = "1" },     -- browser to left portrait
      { kind = "press",  mods = { "ctrl","alt","cmd" }, key = "return" },
    })

    golden("three_monitor_dev_loop", snapshot_moves(hs))
  end)

  it("survives a monitor unplug mid-session without error", function()
    local hs = fresh_hs()
    load_scenario(hs, {
      screens = FIXTURES.three_monitors(),
      windows = {
        { id = 1, title = "Doc", app = "Editor", frame = { x = 2000, y = 100, w = 800, h = 500 } },
      },
      focused = 1,
    })

    run_script(hs, {
      { kind = "press", mods = { "ctrl","alt","cmd" }, key = "l" },
      { kind = "screen_change", world = {
        screens = FIXTURES.two_monitors_horizontal(),
        windows = {
          { id = 1, title = "Doc", app = "Editor", frame = { x = 2000, y = 100, w = 800, h = 500 } },
        },
        focused = 1,
      } },
      -- After unplug, send-to-screen-3 becomes a no-op (only 2 screens now)
      { kind = "press", mods = { "ctrl","alt","cmd" }, key = "3" },
      { kind = "press", mods = { "ctrl","alt","cmd" }, key = "2" },
      { kind = "press", mods = { "ctrl","alt","cmd" }, key = "return" },
    })

    -- We assert only that the window ends on screen 2 and there were no
    -- errors along the way. The golden captures the full trajectory.
    local moves = snapshot_moves(hs)
    assert.is_true(#moves > 0)
    golden("monitor_unplug_recovery", moves)
  end)

  it("nudge burst plus resize chain", function()
    local hs = fresh_hs()
    load_scenario(hs, {
      screens = FIXTURES.laptop_only(),
      windows = {
        { id = 1, title = "Doc", app = "Editor", frame = { x = 100, y = 100, w = 400, h = 300 } },
      },
      focused = 1,
    })

    run_script(hs, {
      { kind = "press", mods = { "ctrl","alt","cmd" }, key = "right" },
      { kind = "press", mods = { "ctrl","alt","cmd" }, key = "right" },
      { kind = "press", mods = { "ctrl","alt","cmd" }, key = "down"  },
      { kind = "press", mods = { "ctrl","alt","cmd" }, key = "]" },
      { kind = "press", mods = { "ctrl","alt","cmd", "shift" }, key = "]" },
      { kind = "press", mods = { "ctrl","alt","cmd" }, key = "c" },
    })

    golden("nudge_and_resize", snapshot_moves(hs))
  end)
end)
