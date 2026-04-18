local hotkeys = require("modules.hotkeys")

describe("hotkeys.build", function()
  local bindings
  before_each(function() bindings = hotkeys.build() end)

  it("generates a non-empty binding list", function()
    assert.is_true(#bindings > 20)
  end)

  it("every binding has mods, key, name, action", function()
    for _, b in ipairs(bindings) do
      assert.is_table(b.mods)
      assert.is_string(b.key)
      assert.is_string(b.name)
      assert.is_function(b.action)
    end
  end)

  it("action names are unique", function()
    local seen = {}
    for _, b in ipairs(bindings) do
      assert.is_nil(seen[b.name], "duplicate name: " .. b.name)
      seen[b.name] = true
    end
  end)

  it("has no (mods, key) conflicts by default", function()
    assert.are.same({}, hotkeys.detect_conflicts(bindings))
  end)

  it("detects conflicts when introduced", function()
    table.insert(bindings, { mods = { "ctrl", "alt", "cmd" }, key = "H", name = "bogus",
      action = function() end })
    local conflicts = hotkeys.detect_conflicts(bindings)
    assert.are.equal(1, #conflicts)
  end)

  it("respects custom hyper prefixes", function()
    local alt_bindings = hotkeys.build({ "cmd" }, { "cmd", "shift" })
    for _, b in ipairs(alt_bindings) do
      local joined = table.concat(b.mods, "+")
      assert.is_true(joined == "cmd" or joined == "cmd+shift")
    end
  end)
end)
