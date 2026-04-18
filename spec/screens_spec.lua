local screens = require("modules.screens")

describe("screens", function()
  local function sample()
    return {
      { id = 3, name = "C", frame = { x = 2000, y = 0, w = 1000, h = 1000 } },
      { id = 1, name = "A", frame = { x = -1000, y = 0, w = 1000, h = 1000 } },
      { id = 2, name = "B", frame = { x = 0, y = 0, w = 1000, h = 1000 } },
    }
  end

  describe("order", function()
    it("sorts left to right, then top to bottom", function()
      local o = screens.order(sample())
      assert.are.equal("A", o[1].name)
      assert.are.equal("B", o[2].name)
      assert.are.equal("C", o[3].name)
    end)

    it("is stable when inputs are already ordered", function()
      local o = screens.order(screens.order(sample()))
      assert.are.same({ "A", "B", "C" }, { o[1].name, o[2].name, o[3].name })
    end)
  end)

  describe("resolver", function()
    it("maps id and name and role", function()
      local r = screens.resolver(sample(), { main = "B", left = 1 })
      assert.are.equal(3, r.count)
      assert.are.equal(2, r:index_for_id(2))
      assert.are.equal(1, r:index_for_name("A"))
      assert.are.equal(2, r:index_for_role("main"))
      assert.are.equal(1, r:index_for_role("left"))
      assert.is_nil(r:index_for_role("nonexistent"))
    end)

    it("cycles next/prev with wrap", function()
      local r = screens.resolver(sample(), {})
      assert.are.equal(2, r:next_index(1, 1))
      assert.are.equal(3, r:next_index(2, 1))
      assert.are.equal(1, r:next_index(3, 1))
      assert.are.equal(3, r:next_index(1, -1))
      assert.are.equal(1, r:next_index(2, -1))
    end)

    it("handles empty screen list gracefully", function()
      local r = screens.resolver({}, {})
      assert.are.equal(0, r.count)
      assert.is_nil(r:next_index(1, 1))
    end)
  end)
end)
