local geometry = require("modules.geometry")

local frame = { x = 0, y = 0, w = 1000, h = 600 }

describe("geometry", function()
  it("rounds fractional rect coords to integers", function()
    local r = geometry.rect(10.4, 20.6, 100.5, 200.5)
    assert.are.same({ x = 10, y = 21, w = 101, h = 201 }, r)
  end)

  it("handles negative coordinates (secondary screens)", function()
    local r = geometry.rect(-1439.9, -0.4, 100.1, 200.1)
    assert.are.same({ x = -1440, y = 0, w = 100, h = 200 }, r)
  end)

  describe("halves & quadrants", function()
    it("splits left/right halves exactly", function()
      assert.are.same({ x = 0,   y = 0, w = 500, h = 600 }, geometry.half(frame, "left"))
      assert.are.same({ x = 500, y = 0, w = 500, h = 600 }, geometry.half(frame, "right"))
    end)

    it("splits top/bottom halves exactly", function()
      assert.are.same({ x = 0, y = 0,   w = 1000, h = 300 }, geometry.half(frame, "top"))
      assert.are.same({ x = 0, y = 300, w = 1000, h = 300 }, geometry.half(frame, "bottom"))
    end)

    it("computes quadrants", function()
      assert.are.same({ x = 0,   y = 0,   w = 500, h = 300 }, geometry.quadrant(frame, "nw"))
      assert.are.same({ x = 500, y = 0,   w = 500, h = 300 }, geometry.quadrant(frame, "ne"))
      assert.are.same({ x = 0,   y = 300, w = 500, h = 300 }, geometry.quadrant(frame, "sw"))
      assert.are.same({ x = 500, y = 300, w = 500, h = 300 }, geometry.quadrant(frame, "se"))
    end)

    it("rejects unknown halves/quadrants", function()
      assert.has_error(function() geometry.half(frame, "bogus") end)
      assert.has_error(function() geometry.quadrant(frame, "diagonal") end)
    end)
  end)

  describe("grid_cell", function()
    it("lays out a 3x3 grid exactly covering the frame", function()
      local total_w, total_h = 0, 0
      for row = 1, 3 do
        for col = 1, 3 do
          local c = geometry.grid_cell(frame, 3, 3, col, row)
          if row == 1 then total_w = total_w + c.w end
          if col == 1 then total_h = total_h + c.h end
        end
      end
      -- Rounding may shift by 1px across the sum; must cover the full frame ±1px.
      assert.is_true(math.abs(total_w - frame.w) <= 1, "width sum " .. total_w)
      assert.is_true(math.abs(total_h - frame.h) <= 1, "height sum " .. total_h)
    end)

    it("supports column/row spans", function()
      local c = geometry.grid_cell(frame, 4, 2, 2, 1, 2, 2)
      assert.are.same({ x = 250, y = 0, w = 500, h = 600 }, c)
    end)

    it("validates bounds", function()
      assert.has_error(function() geometry.grid_cell(frame, 3, 3, 0, 1) end)
      assert.has_error(function() geometry.grid_cell(frame, 3, 3, 4, 1) end)
    end)
  end)

  describe("move_to_screen", function()
    local from = { x = 0, y = 0, w = 1000, h = 1000 }
    local to   = { x = 5000, y = -200, w = 2000, h = 500 }

    it("ratios mode preserves relative position & size", function()
      local rect = { x = 250, y = 250, w = 500, h = 500 }  -- center 50%
      local moved = geometry.move_to_screen(rect, from, to, "ratios")
      assert.are.same({ x = 5500, y = -75, w = 1000, h = 250 }, moved)
    end)

    it("size mode preserves pixel size and clamps inside target", function()
      local rect = { x = 900, y = 900, w = 300, h = 300 }
      local moved = geometry.move_to_screen(rect, from, to, "size")
      -- rect extends past from; ratio origin places it past 'to' too, clamps in.
      assert.is_true(moved.w == 300 and moved.h == 300)
      assert.is_true(moved.x + moved.w <= to.x + to.w)
      assert.is_true(moved.y + moved.h <= to.y + to.h)
    end)

    it("center mode keeps size, centers on target", function()
      local rect = { x = 0, y = 0, w = 400, h = 200 }
      local moved = geometry.move_to_screen(rect, from, to, "center")
      assert.are.same({ x = 5800, y = -50, w = 400, h = 200 }, moved)
    end)

    it("rejects unknown mode", function()
      assert.has_error(function()
        geometry.move_to_screen({x=0,y=0,w=1,h=1}, from, to, "bogus")
      end)
    end)
  end)

  describe("nudge / resize", function()
    it("nudges by one grid step and clamps at edges", function()
      local rect = { x = 0, y = 0, w = 200, h = 200 }
      local left_of_origin = geometry.nudge(rect, frame, "left", 10, 10)
      assert.are.equal(frame.x, left_of_origin.x)
      local right_one = geometry.nudge(rect, frame, "right", 10, 10)
      assert.are.equal(100, right_one.x)
      local down_one = geometry.nudge(rect, frame, "down", 10, 10)
      assert.are.equal(60, down_one.y)
    end)

    it("nudging past the far edge clamps", function()
      local rect = { x = 900, y = 500, w = 100, h = 100 }
      local r = geometry.nudge(rect, frame, "right", 10, 10)
      assert.are.equal(900, r.x)
      local d = geometry.nudge(rect, frame, "down", 10, 10)
      assert.are.equal(500, d.y)
    end)

    it("resize_width grows by one column anchored left", function()
      local rect = { x = 100, y = 100, w = 200, h = 200 }
      local wider = geometry.resize_width(rect, frame, 1, 10)
      assert.are.equal(100, wider.x)
      assert.are.equal(300, wider.w)
    end)

    it("resize never goes below one step or beyond the frame", function()
      local rect = { x = 100, y = 100, w = 50, h = 50 }
      local narrower = geometry.resize_width(rect, frame, -10, 10)
      assert.is_true(narrower.w >= 100)  -- one column = 100 px
      local huge = geometry.resize_width(rect, frame, 100, 10)
      assert.is_true(huge.x + huge.w <= frame.x + frame.w)
    end)
  end)

  describe("screen_for_rect", function()
    it("returns the screen containing the most of the rect", function()
      local screens = {
        { frame = { x = 0,    y = 0, w = 1000, h = 1000 } },
        { frame = { x = 1000, y = 0, w = 1000, h = 1000 } },
      }
      assert.are.equal(1, geometry.screen_for_rect(screens, {x=100,y=100,w=50,h=50}))
      assert.are.equal(2, geometry.screen_for_rect(screens, {x=1500,y=100,w=50,h=50}))
      -- Straddling — more on the right
      assert.are.equal(2, geometry.screen_for_rect(screens, {x=900,y=100,w=500,h=50}))
    end)

    it("returns nil for empty screen list", function()
      assert.is_nil(geometry.screen_for_rect({}, {x=0,y=0,w=10,h=10}))
    end)
  end)

  describe("ratios round-trip", function()
    it("ratios_of ∘ fractional is identity", function()
      local rect = { x = 123, y = 45, w = 678, h = 234 }
      local r = geometry.ratios_of(rect, frame)
      local back = geometry.fractional(frame, r)
      assert.are.same(rect, back)
    end)
  end)
end)
