local actions = require("modules.actions")
local screens_mod = require("modules.screens")

local function make_ctx(fixture, win_frame, screen_index)
  local ordered = screens_mod.order(fixture)
  return {
    window = { frame = win_frame },
    screen_index = screen_index or 2,
    screens = ordered,
    resolver = screens_mod.resolver(fixture, { left = 1, main = 2, right = 3 }),
    grid = { cols = 12, rows = 8 },
  }
end

describe("actions on current screen", function()
  local ctx
  before_each(function()
    ctx = make_ctx(FIXTURES.three_monitors(), { x = 100, y = 100, w = 600, h = 400 }, 2)
  end)

  it("left_half lands on left of current screen frame", function()
    local r = actions.left_half(ctx)
    local screen = ctx.screens[2].frame
    assert.are.equal(screen.x, r.x)
    assert.are.equal(screen.y, r.y)
    assert.are.equal(math.floor(screen.w / 2 + 0.5), r.w)
    assert.are.equal(screen.h, r.h)
  end)

  it("maximize matches the current screen frame exactly", function()
    local r = actions.maximize(ctx)
    assert.are.same(ctx.screens[2].frame, r)
  end)

  it("center keeps window size and centers within screen", function()
    local r = actions.center(ctx)
    assert.are.equal(ctx.window.frame.w, r.w)
    assert.are.equal(ctx.window.frame.h, r.h)
    local screen = ctx.screens[2].frame
    assert.are.equal(math.floor(screen.x + (screen.w - r.w) / 2 + 0.5), r.x)
  end)

  it("grid3x3 cell 5 is the center cell", function()
    local r = actions.grid3x3(ctx, 5)
    local screen = ctx.screens[2].frame
    assert.are.equal(math.floor(screen.x + screen.w / 3 + 0.5), r.x)
    assert.are.equal(math.floor(screen.y + screen.h / 3 + 0.5), r.y)
  end)

  it("grid3x3 rejects out-of-range cell", function()
    assert.has_error(function() actions.grid3x3(ctx, 0) end)
    assert.has_error(function() actions.grid3x3(ctx, 10) end)
  end)
end)

describe("cross-screen actions", function()
  it("send_to_screen preserves relative position and size", function()
    local ctx = make_ctx(FIXTURES.three_monitors(), { x = 300, y = 200, w = 600, h = 400 }, 2)
    local from = ctx.screens[2].frame
    local r = actions.send_to_screen(ctx, 3, "ratios")
    local to = ctx.screens[3].frame
    -- Ratio of r within 'to' must equal ratio of original within 'from'.
    local function ratio(rect, screen)
      return {
        (rect.x - screen.x) / screen.w,
        (rect.y - screen.y) / screen.h,
        rect.w / screen.w,
        rect.h / screen.h,
      }
    end
    local expected = ratio(ctx.window.frame, from)
    local actual = ratio(r, to)
    for i = 1, 4 do
      assert.is_true(math.abs(expected[i] - actual[i]) < 0.002,
        "ratio " .. i .. " off: expected " .. expected[i] .. " got " .. actual[i])
    end
  end)

  it("send_to_screen is a no-op when target screen missing", function()
    local ctx = make_ctx(FIXTURES.laptop_only(), { x = 100, y = 100, w = 200, h = 200 }, 1)
    local r = actions.send_to_screen(ctx, 5, "ratios")
    assert.is_nil(r)
  end)

  it("send_to_screen is a no-op when target equals current screen", function()
    local ctx = make_ctx(FIXTURES.three_monitors(), { x = 100, y = 100, w = 200, h = 200 }, 2)
    assert.is_nil(actions.send_to_screen(ctx, 2, "ratios"))
  end)

  it("send_to_role uses the role_map", function()
    local ctx = make_ctx(FIXTURES.three_monitors(), { x = 0, y = 0, w = 100, h = 100 }, 2)
    local r = actions.send_to_role(ctx, "right", "ratios")
    local right_frame = ctx.screens[3].frame
    assert.is_true(r.x >= right_frame.x and r.x < right_frame.x + right_frame.w)
  end)

  it("send_to_next_screen cycles through screens", function()
    local ctx = make_ctx(FIXTURES.three_monitors(), { x = 0, y = 0, w = 100, h = 100 }, 2)
    local r = actions.send_to_next_screen(ctx, 1, "ratios")
    assert.is_true(r.x >= ctx.screens[3].frame.x)
  end)

  it("send_then composes move + sub-action on destination", function()
    local ctx = make_ctx(FIXTURES.three_monitors(), { x = 100, y = 100, w = 400, h = 300 }, 2)
    local r = actions.send_then(ctx, 3, actions.right_half)
    local right = ctx.screens[3].frame
    assert.are.equal(right.x + math.floor(right.w / 2 + 0.5), r.x)
    assert.are.equal(math.floor(right.w / 2 + 0.5), r.w)
    assert.are.equal(right.h, r.h)
  end)
end)

describe("nudge/resize actions", function()
  it("nudge right shifts the window by one grid column", function()
    local ctx = make_ctx(FIXTURES.three_monitors(), { x = 0, y = 0, w = 500, h = 300 }, 2)
    local r = actions.nudge(ctx, "right")
    local step = ctx.screens[2].frame.w / ctx.grid.cols
    assert.are.equal(math.floor(step + 0.5), r.x)
  end)

  it("wider grows the window but stays inside the screen", function()
    local ctx = make_ctx(FIXTURES.three_monitors(), { x = 0, y = 0, w = 500, h = 300 }, 2)
    local r = actions.wider(ctx)
    assert.is_true(r.w > 500)
    assert.is_true(r.x + r.w <= ctx.screens[2].frame.x + ctx.screens[2].frame.w)
  end)
end)
