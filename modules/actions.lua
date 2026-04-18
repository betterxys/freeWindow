-- High-level window actions, expressed as pure functions.
--
-- Every action takes a `ctx` table describing the world and returns either
-- a new rectangle (the desired window frame in global coordinates) or a
-- command table (see `layouts.lua`). Actions NEVER call into `hs.*`; the
-- driver is responsible for turning their output into actual window moves.
--
-- `ctx` shape:
--
--     {
--       window = { frame = rect },            -- the currently focused window
--       screen_index = int,                   -- screen currently hosting it
--       screens = { frame = rect, ... }[],    -- all screens in stable order
--       resolver = screens.resolver(...),     -- role/id/index helpers
--       grid = { cols = int, rows = int },    -- nudge grid
--     }

local geometry = require("modules.geometry")

local M = {}

local function current_frame(ctx)
  return ctx.screens[ctx.screen_index].frame
end

-- === Halves & quadrants (operate on the current screen) ===============

function M.left_half(ctx)   return geometry.half(current_frame(ctx), "left")   end
function M.right_half(ctx)  return geometry.half(current_frame(ctx), "right")  end
function M.top_half(ctx)    return geometry.half(current_frame(ctx), "top")    end
function M.bottom_half(ctx) return geometry.half(current_frame(ctx), "bottom") end

function M.quadrant_nw(ctx) return geometry.quadrant(current_frame(ctx), "nw") end
function M.quadrant_ne(ctx) return geometry.quadrant(current_frame(ctx), "ne") end
function M.quadrant_sw(ctx) return geometry.quadrant(current_frame(ctx), "sw") end
function M.quadrant_se(ctx) return geometry.quadrant(current_frame(ctx), "se") end

function M.maximize(ctx) return geometry.maximize(current_frame(ctx)) end

function M.center(ctx)
  return geometry.centered(current_frame(ctx), ctx.window.frame)
end

-- === Thirds ============================================================

function M.third_left(ctx)    return geometry.third(current_frame(ctx), "left")   end
function M.third_center(ctx)  return geometry.third(current_frame(ctx), "center") end
function M.third_right(ctx)   return geometry.third(current_frame(ctx), "right")  end
function M.two_thirds_left(ctx)  return geometry.two_thirds(current_frame(ctx), "left")  end
function M.two_thirds_right(ctx) return geometry.two_thirds(current_frame(ctx), "right") end

-- === 3x3 Grid =========================================================
-- Cells are numbered 1..9 row-major, i.e. 1 = NW, 5 = center, 9 = SE.

function M.grid3x3(ctx, cell)
  assert(cell >= 1 and cell <= 9, "cell must be in 1..9")
  local col = ((cell - 1) % 3) + 1
  local row = math.floor((cell - 1) / 3) + 1
  return geometry.grid_cell(current_frame(ctx), 3, 3, col, row)
end

-- === Nudging & resize =================================================

function M.nudge(ctx, direction)
  local g = ctx.grid or { cols = 12, rows = 8 }
  return geometry.nudge(ctx.window.frame, current_frame(ctx), direction, g.cols, g.rows)
end

function M.wider(ctx)
  return geometry.resize_width(ctx.window.frame, current_frame(ctx), 1, (ctx.grid or {}).cols)
end
function M.narrower(ctx)
  return geometry.resize_width(ctx.window.frame, current_frame(ctx), -1, (ctx.grid or {}).cols)
end
function M.taller(ctx)
  return geometry.resize_height(ctx.window.frame, current_frame(ctx), 1, (ctx.grid or {}).rows)
end
function M.shorter(ctx)
  return geometry.resize_height(ctx.window.frame, current_frame(ctx), -1, (ctx.grid or {}).rows)
end

-- === Cross-screen =====================================================

--- Send the window to the screen at `target_index`, preserving relative
-- position and size. Returns nil (no-op) if the target screen is missing
-- or is the current screen.
function M.send_to_screen(ctx, target_index, mode)
  mode = mode or "ratios"
  if target_index == ctx.screen_index then return nil end
  local from = ctx.screens[ctx.screen_index].frame
  local to = ctx.screens[target_index] and ctx.screens[target_index].frame
  if not to then return nil end
  return geometry.move_to_screen(ctx.window.frame, from, to, mode)
end

function M.send_to_role(ctx, role, mode)
  local idx = ctx.resolver:index_for_role(role)
  if not idx then return nil end
  return M.send_to_screen(ctx, idx, mode)
end

function M.send_to_next_screen(ctx, step, mode)
  step = step or 1
  local idx = ctx.resolver:next_index(ctx.screen_index, step)
  if not idx or idx == ctx.screen_index then return nil end
  return M.send_to_screen(ctx, idx, mode)
end

--- Send to screen `target_index` AND apply a sub-action (e.g. right_half) on
-- the destination screen. This is what enables "throw to monitor 2, right
-- half, in one shortcut".
function M.send_then(ctx, target_index, sub_action)
  local moved_ctx = {
    window = { frame = M.send_to_screen(ctx, target_index, "ratios") },
    screen_index = target_index,
    screens = ctx.screens,
    resolver = ctx.resolver,
    grid = ctx.grid,
  }
  return sub_action(moved_ctx)
end

return M
