-- End-to-end-on-Linux tests.
--
-- These load the REAL init.lua against the Hammerspoon fake, fire hotkeys,
-- and assert on the setFrame log. If any of these fail, the real Mac almost
-- certainly has a bug too.

local function load_init_fresh()
  -- Reset module cache so init.lua runs top-level code again.
  for name in pairs(package.loaded) do
    if name == "init" or name:match("^modules%.") or name == "hs" or name == "config" then
      package.loaded[name] = nil
    end
  end
  _G.hs = require("hs")
  _G.hs._reset()
  return _G.hs
end

local function push_world(hs, fixture_name, focused_window)
  local screens = FIXTURES[fixture_name]()
  local windows = { focused_window }
  hs._load_world({
    screens = screens,
    windows = windows,
    focused = focused_window.id,
  })
end

describe("E2E: init.lua under the fake", function()
  it("loads without error and installs hotkeys on a 3-monitor setup", function()
    local hs = load_init_fresh()
    push_world(hs, "three_monitors", {
      id = 500, title = "Doc", app = "Editor",
      frame = { x = 100, y = 100, w = 600, h = 400 },
    })
    require("init")
    assert.is_true(#hs._hotkeys() > 20)
    -- No startup alerts about conflicts
    for _, msg in ipairs(hs._alerts()) do
      assert.is_nil(msg:find("conflict"), "unexpected conflict alert: " .. msg)
    end
  end)

  it("⌃⌥⌘+L puts the window into the right half of its screen", function()
    local hs = load_init_fresh()
    push_world(hs, "three_monitors", {
      id = 500, title = "Doc", app = "Editor",
      frame = { x = 100, y = 100, w = 600, h = 400 },
    })
    require("init")
    assert.is_true(hs._press({ "ctrl", "alt", "cmd" }, "l"))
    local last = hs._set_frame_log()[#hs._set_frame_log()]
    -- Built-in screen is the first one ordered by x; x=0 w=1512
    assert.are.equal(756, last.frame.x)
    assert.are.equal(0, last.frame.y)
    assert.are.equal(756, last.frame.w)
    assert.are.equal(982, last.frame.h)
  end)

  it("⌃⌥⌘+3 sends the window to the 3rd screen (right 4K) preserving ratios", function()
    local hs = load_init_fresh()
    -- window occupying middle 50% of the built-in screen
    push_world(hs, "three_monitors", {
      id = 500, title = "Doc", app = "Editor",
      frame = { x = 378, y = 246, w = 756, h = 491 },
    })
    require("init")
    assert.is_true(hs._press({ "ctrl", "alt", "cmd" }, "3"))
    local last = hs._set_frame_log()[#hs._set_frame_log()]
    -- Ordered screens: [1]=Left Portrait@-1440, [2]=Built-in@0, [3]=Right 4K@1512
    -- Built-in is 1512x982; source window occupies middle ~50% (x=378..1134, y=246..737).
    -- Ratios (0.25, 0.2505, 0.5, 0.5001) mapped onto 3840x2160 @ (1512,-589).
    assert.are.equal(2472, last.frame.x)                -- 1512 + round(0.25*3840)
    assert.are.equal(-48, last.frame.y)                 -- -589 + round(0.2505*2160) = -48
    assert.are.equal(1920, last.frame.w)
    assert.are.equal(1080, last.frame.h)
  end)

  it("⌃⌥⌘+Return maximizes to the current screen (not original full-screen)", function()
    local hs = load_init_fresh()
    push_world(hs, "three_monitors", {
      id = 500, title = "Doc", app = "Editor",
      frame = { x = 2000, y = 0, w = 600, h = 400 },
    })
    require("init")
    assert.is_true(hs._press({ "ctrl", "alt", "cmd" }, "return"))
    local last = hs._set_frame_log()[#hs._set_frame_log()]
    -- The window is at x=2000, which sits on screen 3 (Right 4K)
    assert.are.equal(1512, last.frame.x)
    assert.are.equal(-589, last.frame.y)
    assert.are.equal(3840, last.frame.w)
    assert.are.equal(2160, last.frame.h)
  end)

  it("⌃⌥⌘+Shift+5 goes to the center cell of the current screen's 3x3 grid", function()
    local hs = load_init_fresh()
    push_world(hs, "three_monitors", {
      id = 500, title = "Doc", app = "Editor",
      frame = { x = 10, y = 10, w = 100, h = 100 },
    })
    require("init")
    assert.is_true(hs._press({ "ctrl", "alt", "cmd", "shift" }, "5"))
    local last = hs._set_frame_log()[#hs._set_frame_log()]
    -- Built-in screen, 3x3 grid cell 5 => middle third x & middle third y
    assert.are.equal(math.floor(1512/3 + 0.5), last.frame.x)
    assert.are.equal(math.floor(982/3 + 0.5), last.frame.y)
    assert.are.equal(math.floor(1512/3 + 0.5), last.frame.w)
  end)

  it("⌃⌥⌘+right nudges by one grid column and clamps at the right edge", function()
    local hs = load_init_fresh()
    push_world(hs, "three_monitors", {
      id = 500, title = "Doc", app = "Editor",
      frame = { x = 0, y = 0, w = 500, h = 300 },
    })
    require("init")
    assert.is_true(hs._press({ "ctrl", "alt", "cmd" }, "right"))
    local last = hs._set_frame_log()[#hs._set_frame_log()]
    assert.is_true(last.frame.x > 0)
    -- After many nudges we must hit the right edge and clamp
    for _ = 1, 50 do hs._press({ "ctrl", "alt", "cmd" }, "right") end
    last = hs._set_frame_log()[#hs._set_frame_log()]
    assert.are.equal(1512 - 500, last.frame.x)
  end)

  it("laptop-only fallback: send_to_screen_3 is a no-op with no crash", function()
    local hs = load_init_fresh()
    push_world(hs, "laptop_only", {
      id = 500, title = "Doc", app = "Editor",
      frame = { x = 100, y = 100, w = 400, h = 300 },
    })
    require("init")
    local before_log = #hs._set_frame_log()
    assert.is_true(hs._press({ "ctrl", "alt", "cmd" }, "3"))
    assert.are.equal(before_log, #hs._set_frame_log())
  end)

  it("save then restore layout round-trips window positions through serialization", function()
    local hs = load_init_fresh()
    push_world(hs, "three_monitors", {
      id = 500, title = "Doc", app = "Editor",
      frame = { x = 300, y = 100, w = 600, h = 400 },
    })
    -- Load a second visible window so the layout captures more than one.
    table.insert(hs._state().windows,
      { id = 501, title = "Mail", app = "Browser", standard = true, minimized = false,
        frame = { x = 2000, y = 100, w = 800, h = 500 } })
    hs._state().windows[501] = {
      id = 501, title = "Mail", app = "Browser", standard = true, minimized = false,
      frame = { x = 2000, y = 100, w = 800, h = 500 },
    }
    hs._state().window_order[#hs._state().window_order + 1] = 501

    require("init")
    local layouts = require("modules.layouts")
    local driver = require("modules.driver")
    local tmp = os.tmpname()
    driver.save_layout(tmp)
    -- Disturb windows
    hs._state().windows[500].frame = { x = 0, y = 0, w = 100, h = 100 }
    hs._state().windows[501].frame = { x = 0, y = 0, w = 100, h = 100 }
    local plan = driver.restore_layout(tmp)
    assert.are.equal(2, #plan.commands)
    -- After restore, re-capturing should produce the same serialized snapshot.
    local snap_after = layouts.capture(driver.capture_world())
    local f = io.open(tmp, "r")
    local saved = f:read("*a"); f:close()
    assert.are.equal(saved, layouts.serialize(snap_after))
    os.remove(tmp)
  end)
end)
