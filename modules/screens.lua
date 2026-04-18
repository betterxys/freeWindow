-- Stable, user-friendly identification of screens.
--
-- The Hammerspoon API gives us screens in an order that depends on macOS's
-- internal display graph (main first, then others by `hs.screen:id()`). That
-- order is not particularly intuitive when you just want to say "send this
-- window to my left-hand external display".
--
-- This module ranks screens by their *physical position* in the global
-- coordinate space. The result is three conceptual lookups:
--
--   screens.by_index   – stable 1-based index in left→right, top→bottom order
--   screens.by_role    – user-assigned role name (e.g. "left", "main", "right")
--   screens.by_id      – macOS display id
--
-- The only input we take from `hs.*` is a list of frames and ids, so this
-- file is fully testable under Linux.

local M = {}

--- Normalize a list of screens by sorting them left→right, then top→bottom.
-- Each input `screens[i]` must have `id` and `frame = {x,y,w,h}`.
-- Optionally `name` (from `hs.screen:name()`), preserved in output.
function M.order(screens)
  local list = {}
  for i, s in ipairs(screens) do
    list[i] = { id = s.id, frame = s.frame, name = s.name }
  end
  table.sort(list, function(a, b)
    if a.frame.x ~= b.frame.x then return a.frame.x < b.frame.x end
    if a.frame.y ~= b.frame.y then return a.frame.y < b.frame.y end
    return (a.id or 0) < (b.id or 0)
  end)
  return list
end

local Resolver = {}
Resolver.__index = Resolver

function Resolver:frame(i)
  local s = self.ordered[i]
  return s and s.frame or nil
end

function Resolver:index_for_id(id) return self._by_id[id] end
function Resolver:index_for_name(name) return self._by_name[name] end
function Resolver:index_for_role(role) return self._roles[role] end

--- Cycle to the next screen (1-based, wraps around).
function Resolver:next_index(i, step)
  step = step or 1
  if self.count == 0 then return nil end
  local n = ((i - 1 + step) % self.count) + 1
  if n <= 0 then n = n + self.count end
  return n
end

--- Build a resolver from raw screen data and an optional role map.
--
-- `role_map` is a table like `{ left = 1, main = 2, right = 3 }` where values
-- are 1-based indexes into the sorted `order()` output. Callers may also map
-- roles by screen name: `{ main = "Built-in Retina Display" }`.
function M.resolver(screens, role_map)
  local ordered = M.order(screens)
  local by_id, by_name = {}, {}
  for i, s in ipairs(ordered) do
    by_id[s.id] = i
    if s.name then by_name[s.name] = i end
  end

  local roles = {}
  for role, target in pairs(role_map or {}) do
    if type(target) == "number" then
      roles[role] = target
    elseif type(target) == "string" then
      roles[role] = by_name[target]
    end
  end

  return setmetatable({
    ordered = ordered,
    count = #ordered,
    _by_id = by_id,
    _by_name = by_name,
    _roles = roles,
  }, Resolver)
end

return M
