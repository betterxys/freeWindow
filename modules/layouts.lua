-- Save / restore named window layouts.
--
-- Design goals:
--   * "Save" captures every visible standard window and the screen it was on,
--     in ratio form (so restoring on a different monitor arrangement still
--     produces something sensible).
--   * "Restore" is idempotent – re-running it does not compound drift.
--   * The on-disk format is plain Lua (serialized as a return-table) so a
--     user can eyeball it, diff it, or hand-edit.
--   * This module is pure: capture takes a world snapshot, restore returns a
--     list of (window_id -> desired_frame) commands. The driver applies
--     them.

local geometry = require("modules.geometry")

local M = {}

--- Build a snapshot from a world description.
-- `world.windows` is a list of { id, title, app, screen_index, frame }.
-- `world.screens` is a list of { id, name, frame }.
function M.capture(world)
  local snap = {
    version = 1,
    screens = {},
    windows = {},
  }
  for i, s in ipairs(world.screens) do
    snap.screens[i] = { id = s.id, name = s.name, frame = geometry.copy(s.frame) }
  end
  for _, w in ipairs(world.windows) do
    local scr = world.screens[w.screen_index]
    if scr then
      snap.windows[#snap.windows + 1] = {
        id = w.id,
        title = w.title,
        app = w.app,
        screen_index = w.screen_index,
        screen_name = scr.name,
        ratios = geometry.ratios_of(w.frame, scr.frame),
      }
    end
  end
  return snap
end

--- Plan a restore against a (possibly different) world.
-- Matching strategy for each saved window:
--   1. by window id (only if the id still exists); else
--   2. by (app, title) exact match; else
--   3. by (app) alone if unique among the current windows; else
--   4. skipped (recorded in `unresolved`).
--
-- For the screen, we resolve by name first, then by index in the new world.
function M.plan_restore(snap, world)
  local commands = {}
  local unresolved = {}

  local by_id = {}
  local by_app_title = {}
  local by_app = {}
  for _, w in ipairs(world.windows) do
    by_id[w.id] = w
    by_app_title[(w.app or "") .. "\0" .. (w.title or "")] = w
    by_app[w.app or ""] = (by_app[w.app or ""] or 0) + 1
  end
  local by_app_unique = {}
  for _, w in ipairs(world.windows) do
    if by_app[w.app or ""] == 1 then
      by_app_unique[w.app or ""] = w
    end
  end

  local screen_by_name = {}
  for i, s in ipairs(world.screens) do
    if s.name then screen_by_name[s.name] = i end
  end

  for _, saved in ipairs(snap.windows) do
    local match = by_id[saved.id]
      or by_app_title[(saved.app or "") .. "\0" .. (saved.title or "")]
      or by_app_unique[saved.app or ""]
    local target_screen_idx = screen_by_name[saved.screen_name] or saved.screen_index
    local target_screen = world.screens[target_screen_idx]
    if not (match and target_screen) then
      unresolved[#unresolved + 1] = { saved = saved, reason = not match and "no-window" or "no-screen" }
    else
      commands[#commands + 1] = {
        window_id = match.id,
        frame = geometry.fractional(target_screen.frame, saved.ratios),
      }
    end
  end

  return { commands = commands, unresolved = unresolved }
end

--- Serialize a snapshot as a Lua expression. Deterministic key ordering so
-- on-disk diffs are minimal.
function M.serialize(snap)
  local function fmt(v, indent)
    indent = indent or ""
    local t = type(v)
    if t == "number" then
      if v % 1 == 0 then return tostring(math.tointeger(v) or v) end
      return string.format("%.6f", v)
    elseif t == "string" then
      return string.format("%q", v)
    elseif t == "boolean" or t == "nil" then
      return tostring(v)
    elseif t == "table" then
      local keys = {}
      local is_array = true
      local max_n = 0
      for k in pairs(v) do
        keys[#keys + 1] = k
        if type(k) ~= "number" then is_array = false end
        if type(k) == "number" and k > max_n then max_n = k end
      end
      if is_array and max_n == #keys then
        local parts = {}
        for i = 1, #v do parts[i] = fmt(v[i], indent .. "  ") end
        return "{ " .. table.concat(parts, ", ") .. " }"
      end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      local parts = {}
      for _, k in ipairs(keys) do
        local key_s = type(k) == "string" and k:match("^[%a_][%w_]*$")
          and k or "[" .. fmt(k) .. "]"
        parts[#parts + 1] = indent .. "  " .. key_s .. " = " .. fmt(v[k], indent .. "  ")
      end
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    end
    error("cannot serialize type " .. t)
  end
  return "return " .. fmt(snap) .. "\n"
end

--- Deserialize a snapshot (inverse of `serialize`).
function M.deserialize(str)
  local chunk, err = load(str, "=(snapshot)", "t", {})
  if not chunk then error("failed to parse snapshot: " .. tostring(err)) end
  return chunk()
end

return M
