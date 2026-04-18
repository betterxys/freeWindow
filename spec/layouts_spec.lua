local layouts = require("modules.layouts")

local function three_monitor_world()
  local screens = {
    { id = 1, name = "A", frame = { x = 0,    y = 0, w = 1000, h = 800 } },
    { id = 2, name = "B", frame = { x = 1000, y = 0, w = 2000, h = 1200 } },
  }
  local windows = {
    { id = 10, title = "Doc",  app = "Editor",  screen_index = 1,
      frame = { x = 100, y = 100, w = 800, h = 600 } },
    { id = 11, title = "Mail", app = "Browser", screen_index = 2,
      frame = { x = 1500, y = 100, w = 1000, h = 800 } },
  }
  return { screens = screens, windows = windows }
end

describe("layouts.capture", function()
  it("stores ratios, not pixel coordinates", function()
    local snap = layouts.capture(three_monitor_world())
    assert.are.equal(2, #snap.windows)
    for _, w in ipairs(snap.windows) do
      for _, key in ipairs({ "x", "y", "w", "h" }) do
        assert.is_true(w.ratios[key] >= 0 and w.ratios[key] <= 1.0001,
          "ratio out of range: " .. key .. "=" .. tostring(w.ratios[key]))
      end
    end
  end)

  it("round-trips through serialize/deserialize byte-stable", function()
    local snap = layouts.capture(three_monitor_world())
    local s1 = layouts.serialize(snap)
    local snap2 = layouts.deserialize(s1)
    local s2 = layouts.serialize(snap2)
    assert.are.equal(s1, s2)
  end)
end)

describe("layouts.plan_restore", function()
  it("matches windows by id when they still exist", function()
    local w1 = three_monitor_world()
    local snap = layouts.capture(w1)
    local plan = layouts.plan_restore(snap, w1)
    assert.are.equal(2, #plan.commands)
    assert.are.equal(0, #plan.unresolved)
  end)

  it("matches by (app, title) when ids are reassigned", function()
    local w1 = three_monitor_world()
    local snap = layouts.capture(w1)
    local w2 = three_monitor_world()
    -- Simulate app restart: window ids changed.
    w2.windows[1].id = 777
    w2.windows[2].id = 888
    local plan = layouts.plan_restore(snap, w2)
    assert.are.equal(2, #plan.commands)
    assert.are.equal(0, #plan.unresolved)
  end)

  it("is idempotent: applying commands, then recapturing, yields same ratios", function()
    local w1 = three_monitor_world()
    local snap = layouts.capture(w1)
    local plan = layouts.plan_restore(snap, w1)
    for _, cmd in ipairs(plan.commands) do
      for _, win in ipairs(w1.windows) do
        if win.id == cmd.window_id then win.frame = cmd.frame end
      end
    end
    local snap2 = layouts.capture(w1)
    assert.are.equal(layouts.serialize(snap), layouts.serialize(snap2))
  end)

  it("records unresolved windows when matching fails", function()
    local w1 = three_monitor_world()
    local snap = layouts.capture(w1)
    local w2 = { screens = w1.screens, windows = {} }
    local plan = layouts.plan_restore(snap, w2)
    assert.are.equal(0, #plan.commands)
    assert.are.equal(2, #plan.unresolved)
  end)

  it("remaps to a renamed/reindexed screen by name", function()
    local w1 = three_monitor_world()
    local snap = layouts.capture(w1)
    local w2 = {
      screens = {
        { id = 99, name = "B", frame = { x = 0,    y = 0, w = 2000, h = 1200 } },
        { id = 98, name = "A", frame = { x = 2000, y = 0, w = 1000, h = 800 } },
      },
      windows = w1.windows,
    }
    local plan = layouts.plan_restore(snap, w2)
    assert.are.equal(2, #plan.commands)
    for _, cmd in ipairs(plan.commands) do
      if cmd.window_id == 10 then
        -- window "Doc" was on screen "A", which is now at x = 2000..3000
        assert.is_true(cmd.frame.x >= 2000)
      elseif cmd.window_id == 11 then
        assert.is_true(cmd.frame.x < 2000)
      end
    end
  end)
end)
