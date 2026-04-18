-- Central hotkey table. Each entry is a declarative spec that both the
-- live Hammerspoon runtime and the offline validator/tests can consume.
--
-- Modifiers use Hammerspoon's string form:
--   "cmd", "alt", "ctrl", "shift"  and their aliases "⌘", "⌥", "⌃", "⇧".
-- The default "hyper" prefix is ctrl+alt+cmd, per the established community
-- convention. You can override it in your local `config.lua`.

local actions = require("modules.actions")

local M = {}

M.DEFAULT_HYPER = { "ctrl", "alt", "cmd" }
M.DEFAULT_HYPER_SHIFT = { "ctrl", "alt", "cmd", "shift" }

--- Return the full binding list given modifier sets.
-- `hyper` and `hyper_shift` are mod tables. This keeps tests from having to
-- know about the defaults.
function M.build(hyper, hyper_shift)
  hyper = hyper or M.DEFAULT_HYPER
  hyper_shift = hyper_shift or M.DEFAULT_HYPER_SHIFT

  local function bind(mods, key, name, action)
    return { mods = mods, key = key, name = name, action = action }
  end

  local b = {}

  -- Halves
  b[#b+1] = bind(hyper, "h", "left_half",   actions.left_half)
  b[#b+1] = bind(hyper, "l", "right_half",  actions.right_half)
  b[#b+1] = bind(hyper, "k", "top_half",    actions.top_half)
  b[#b+1] = bind(hyper, "j", "bottom_half", actions.bottom_half)

  -- Quadrants
  b[#b+1] = bind(hyper, "u", "quadrant_nw", actions.quadrant_nw)
  b[#b+1] = bind(hyper, "i", "quadrant_ne", actions.quadrant_ne)
  b[#b+1] = bind(hyper, "n", "quadrant_sw", actions.quadrant_sw)
  b[#b+1] = bind(hyper, "m", "quadrant_se", actions.quadrant_se)

  -- Maximize, center
  b[#b+1] = bind(hyper, "return", "maximize", actions.maximize)
  b[#b+1] = bind(hyper, "c",      "center",   actions.center)

  -- Thirds
  b[#b+1] = bind(hyper_shift, "h", "third_left",      actions.third_left)
  b[#b+1] = bind(hyper_shift, "j", "third_center",    actions.third_center)
  b[#b+1] = bind(hyper_shift, "l", "third_right",     actions.third_right)
  b[#b+1] = bind(hyper_shift, "u", "two_thirds_left", actions.two_thirds_left)
  b[#b+1] = bind(hyper_shift, "o", "two_thirds_right", actions.two_thirds_right)

  -- Nudge (arrow keys)
  b[#b+1] = bind(hyper, "left",  "nudge_left",  function(ctx) return actions.nudge(ctx, "left")  end)
  b[#b+1] = bind(hyper, "right", "nudge_right", function(ctx) return actions.nudge(ctx, "right") end)
  b[#b+1] = bind(hyper, "up",    "nudge_up",    function(ctx) return actions.nudge(ctx, "up")    end)
  b[#b+1] = bind(hyper, "down",  "nudge_down",  function(ctx) return actions.nudge(ctx, "down")  end)

  -- Resize with bracket keys
  b[#b+1] = bind(hyper,       "]", "wider",    actions.wider)
  b[#b+1] = bind(hyper,       "[", "narrower", actions.narrower)
  b[#b+1] = bind(hyper_shift, "]", "taller",   actions.taller)
  b[#b+1] = bind(hyper_shift, "[", "shorter",  actions.shorter)

  -- 3x3 grid on current screen (hyper+shift+1..9)
  for cell = 1, 9 do
    b[#b+1] = bind(hyper_shift, tostring(cell), "grid3x3_" .. cell,
      function(ctx) return actions.grid3x3(ctx, cell) end)
  end

  -- Send to absolute screen 1..3 (hyper + 1/2/3)
  for idx = 1, 3 do
    b[#b+1] = bind(hyper, tostring(idx), "send_to_screen_" .. idx,
      function(ctx) return actions.send_to_screen(ctx, idx, "ratios") end)
  end

  -- Cycle screens (hyper + , and .)
  b[#b+1] = bind(hyper, ",", "send_prev_screen",
    function(ctx) return actions.send_to_next_screen(ctx, -1, "ratios") end)
  b[#b+1] = bind(hyper, ".", "send_next_screen",
    function(ctx) return actions.send_to_next_screen(ctx, 1, "ratios") end)

  return b
end

--- Detect duplicate (mods, key) pairs in a binding list.
-- Returns an array of { key = k, mods = normalized_mods, names = {...} }
-- for any collisions. An empty return means "all good".
function M.detect_conflicts(bindings)
  local seen = {}
  local conflicts = {}
  for _, bnd in ipairs(bindings) do
    local mods = {}
    for _, m in ipairs(bnd.mods) do mods[#mods+1] = m:lower() end
    table.sort(mods)
    local signature = table.concat(mods, "+") .. "/" .. bnd.key:lower()
    seen[signature] = seen[signature] or { mods = mods, key = bnd.key, names = {} }
    local entry = seen[signature]
    entry.names[#entry.names + 1] = bnd.name
  end
  for _, e in pairs(seen) do
    if #e.names > 1 then conflicts[#conflicts + 1] = e end
  end
  return conflicts
end

return M
