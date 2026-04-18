-- Pure geometry helpers used by the window-placement engine.
--
-- Everything in this file is a pure function over plain Lua tables:
--
--     frame = { x = number, y = number, w = number, h = number }
--     rect  = same shape
--
-- There are zero references to `hs.*`, so every function here is fully
-- testable under the Linux/busted runner.
--
-- Coordinate convention (matches macOS / Hammerspoon):
--
--   * Global coordinate space: origin (0, 0) is the top-left of the primary
--     screen. Secondary screens may have negative x or y.
--   * `frame` refers to a screen's *usable* area (excluding menu bar / Dock),
--     i.e. `hs.screen:frame()` on the real Mac.
--   * All rectangles are expressed in global coordinates unless explicitly
--     stated otherwise.

local M = {}

-- Epsilon used when rounding fractional pixels.
local EPS = 1e-6

local function round(n)
  if n >= 0 then
    return math.floor(n + 0.5 + EPS)
  else
    return -math.floor(-n + 0.5 + EPS)
  end
end

--- Make a new rectangle with rounded integer coordinates.
-- Hammerspoon accepts floats but macOS rounds internally; rounding here keeps
-- golden snapshots stable across platforms.
function M.rect(x, y, w, h)
  return { x = round(x), y = round(y), w = round(w), h = round(h) }
end

--- Shallow copy of a rect/frame.
function M.copy(r)
  return { x = r.x, y = r.y, w = r.w, h = r.h }
end

--- Structural equality for rectangles.
function M.equal(a, b)
  if a == nil or b == nil then return a == b end
  return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
end

--- Compute a sub-rectangle of `frame` from fractional coordinates.
-- `f = { x = x_frac, y = y_frac, w = w_frac, h = h_frac }` each in [0, 1].
-- Example: left half = { x = 0, y = 0, w = 0.5, h = 1 }.
function M.fractional(frame, f)
  return M.rect(
    frame.x + frame.w * f.x,
    frame.y + frame.h * f.y,
    frame.w * f.w,
    frame.h * f.h
  )
end

--- Cell in a uniform `cols x rows` grid on `frame`.
-- col, row are 1-indexed. span defaults to 1 cell.
function M.grid_cell(frame, cols, rows, col, row, span_cols, span_rows)
  assert(col >= 1 and col <= cols, "col out of range")
  assert(row >= 1 and row <= rows, "row out of range")
  span_cols = span_cols or 1
  span_rows = span_rows or 1
  return M.rect(
    frame.x + frame.w * (col - 1) / cols,
    frame.y + frame.h * (row - 1) / rows,
    frame.w * span_cols / cols,
    frame.h * span_rows / rows
  )
end

--- Halves: "left" / "right" / "top" / "bottom".
function M.half(frame, which)
  if which == "left" then
    return M.fractional(frame, { x = 0, y = 0, w = 0.5, h = 1 })
  elseif which == "right" then
    return M.fractional(frame, { x = 0.5, y = 0, w = 0.5, h = 1 })
  elseif which == "top" then
    return M.fractional(frame, { x = 0, y = 0, w = 1, h = 0.5 })
  elseif which == "bottom" then
    return M.fractional(frame, { x = 0, y = 0.5, w = 1, h = 0.5 })
  end
  error("unknown half: " .. tostring(which))
end

--- Quadrants: "nw" / "ne" / "sw" / "se".
function M.quadrant(frame, which)
  local mapping = {
    nw = { x = 0,   y = 0,   w = 0.5, h = 0.5 },
    ne = { x = 0.5, y = 0,   w = 0.5, h = 0.5 },
    sw = { x = 0,   y = 0.5, w = 0.5, h = 0.5 },
    se = { x = 0.5, y = 0.5, w = 0.5, h = 0.5 },
  }
  local f = mapping[which] or error("unknown quadrant: " .. tostring(which))
  return M.fractional(frame, f)
end

--- Horizontal thirds: "left" / "center" / "right".
function M.third(frame, which)
  local mapping = {
    left   = { x = 0,     y = 0, w = 1/3, h = 1 },
    center = { x = 1/3,   y = 0, w = 1/3, h = 1 },
    right  = { x = 2/3,   y = 0, w = 1/3, h = 1 },
  }
  local f = mapping[which] or error("unknown third: " .. tostring(which))
  return M.fractional(frame, f)
end

--- Two-thirds: "left" or "right".
function M.two_thirds(frame, which)
  if which == "left" then
    return M.fractional(frame, { x = 0, y = 0, w = 2/3, h = 1 })
  elseif which == "right" then
    return M.fractional(frame, { x = 1/3, y = 0, w = 2/3, h = 1 })
  end
  error("unknown two_thirds: " .. tostring(which))
end

--- Maximize within a screen's usable frame.
function M.maximize(frame)
  return M.copy(frame)
end

--- Keep current size, center on `frame`.
function M.centered(frame, rect)
  return M.rect(
    frame.x + (frame.w - rect.w) / 2,
    frame.y + (frame.h - rect.h) / 2,
    rect.w,
    rect.h
  )
end

--- Describe `rect` as fractions of `frame`. Inverse of `fractional`.
-- If `rect` extends beyond `frame`, fractions can exceed [0, 1]; that is
-- intentional so callers can choose to clamp or not.
function M.ratios_of(rect, frame)
  assert(frame.w > 0 and frame.h > 0, "frame must be non-empty")
  return {
    x = (rect.x - frame.x) / frame.w,
    y = (rect.y - frame.y) / frame.h,
    w = rect.w / frame.w,
    h = rect.h / frame.h,
  }
end

--- Clamp `rect` so it fits entirely within `frame`.
-- Width/height are preserved if possible, otherwise shrunk to fit.
function M.clamp(rect, frame)
  local w = math.min(rect.w, frame.w)
  local h = math.min(rect.h, frame.h)
  local x = math.max(frame.x, math.min(rect.x, frame.x + frame.w - w))
  local y = math.max(frame.y, math.min(rect.y, frame.y + frame.h - h))
  return M.rect(x, y, w, h)
end

--- Move `rect` to a different screen while preserving either
--   - `"ratios"`:  relative position & size on the target screen, or
--   - `"size"`:    exact pixel size, placed at the ratio-equivalent origin
--                  then clamped to fit, or
--   - `"center"`:  exact pixel size, centered on the target.
function M.move_to_screen(rect, from_frame, to_frame, mode)
  mode = mode or "ratios"
  if mode == "ratios" then
    return M.fractional(to_frame, M.ratios_of(rect, from_frame))
  elseif mode == "size" then
    local r = M.ratios_of(rect, from_frame)
    local target = M.rect(
      to_frame.x + to_frame.w * r.x,
      to_frame.y + to_frame.h * r.y,
      rect.w,
      rect.h
    )
    return M.clamp(target, to_frame)
  elseif mode == "center" then
    return M.centered(to_frame, rect)
  end
  error("unknown move_to_screen mode: " .. tostring(mode))
end

--- Nudge by one grid cell in a cardinal direction. `cols`/`rows` form a
-- virtual grid over `frame`. Movement is clamped to the frame.
function M.nudge(rect, frame, direction, cols, rows)
  cols = cols or 12
  rows = rows or 8
  local step_x = frame.w / cols
  local step_y = frame.h / rows
  local dx, dy = 0, 0
  if direction == "left"  then dx = -step_x
  elseif direction == "right" then dx = step_x
  elseif direction == "up"    then dy = -step_y
  elseif direction == "down"  then dy = step_y
  else error("unknown nudge direction: " .. tostring(direction)) end
  local target = M.rect(rect.x + dx, rect.y + dy, rect.w, rect.h)
  return M.clamp(target, frame)
end

--- Grow/shrink the rect width by one grid column, anchored on its left edge.
function M.resize_width(rect, frame, delta_cols, cols)
  cols = cols or 12
  local step = frame.w / cols
  local new_w = math.max(step, math.min(frame.w, rect.w + step * delta_cols))
  return M.clamp(M.rect(rect.x, rect.y, new_w, rect.h), frame)
end

--- Grow/shrink the rect height by one grid row, anchored on its top edge.
function M.resize_height(rect, frame, delta_rows, rows)
  rows = rows or 8
  local step = frame.h / rows
  local new_h = math.max(step, math.min(frame.h, rect.h + step * delta_rows))
  return M.clamp(M.rect(rect.x, rect.y, rect.w, new_h), frame)
end

--- Test if a rect is fully inside a frame (inclusive edges).
function M.contains(frame, rect)
  return rect.x >= frame.x
     and rect.y >= frame.y
     and rect.x + rect.w <= frame.x + frame.w
     and rect.y + rect.h <= frame.y + frame.h
end

--- Return the screen whose frame contains the largest portion of `rect`.
-- `screens` is a list of `{ frame = frame, ... }` items. Returns the index
-- (1-based) or nil if `screens` is empty.
function M.screen_for_rect(screens, rect)
  local best_idx, best_area = nil, -1
  for i, s in ipairs(screens) do
    local fx1, fy1 = s.frame.x, s.frame.y
    local fx2, fy2 = s.frame.x + s.frame.w, s.frame.y + s.frame.h
    local rx1, ry1 = rect.x, rect.y
    local rx2, ry2 = rect.x + rect.w, rect.y + rect.h
    local ox = math.max(0, math.min(fx2, rx2) - math.max(fx1, rx1))
    local oy = math.max(0, math.min(fy2, ry2) - math.max(fy1, ry1))
    local area = ox * oy
    if area > best_area then
      best_area = area
      best_idx = i
    end
  end
  return best_idx
end

return M
