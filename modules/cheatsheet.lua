-- modules/cheatsheet.lua
-- Floating hotkey-reference panel (hs.webview).
--
-- Usage in init.lua:
--   local cheatsheet = require("modules.cheatsheet")
--   cheatsheet.toggle(all_bindings, M.config.hyper)
--
-- Pressing the bound key again (or clicking ✕) closes the panel.

local M = {}
local _view = nil   -- hs.webview instance while panel is open, nil otherwise
local _esc  = nil   -- hs.hotkey for Esc-to-dismiss while panel is open

-- ── Symbol / format helpers ──────────────────────────────────────────────────

local MOD_SYM   = { ctrl = "⌃", alt = "⌥", cmd = "⌘", shift = "⇧" }
local MOD_ORDER = { "ctrl", "alt", "cmd", "shift" }

local KEY_ALIAS = {
  ["return"] = "↩",
  left = "←", right = "→", up = "↑", down = "↓",
  [","] = ",", ["."] = ".", ["/"] = "/",
  ["["] = "[", ["]"] = "]",
}

local function fmt_mods(mods)
  local set, s = {}, ""
  for _, m in ipairs(mods) do set[m:lower()] = true end
  for _, m in ipairs(MOD_ORDER) do
    if set[m] then s = s .. (MOD_SYM[m] or m) end
  end
  return s
end

local function fmt_key(k)
  return KEY_ALIAS[k:lower()] or k:upper()
end

local function fmt_combo(b)
  return fmt_mods(b.mods) .. fmt_key(b.key)
end

-- ── Human-readable names ─────────────────────────────────────────────────────

local LABEL = {
  left_half        = "Left Half",
  right_half       = "Right Half",
  top_half         = "Top Half",
  bottom_half      = "Bottom Half",
  quadrant_nw      = "Quadrant NW",
  quadrant_ne      = "Quadrant NE",
  quadrant_sw      = "Quadrant SW",
  quadrant_se      = "Quadrant SE",
  maximize         = "Maximize",
  center           = "Center",
  third_left       = "Left Third",
  third_center     = "Center Third",
  third_right      = "Right Third",
  two_thirds_left  = "Left ⅔",
  two_thirds_right = "Right ⅔",
  nudge_left       = "Nudge ←",
  nudge_right      = "Nudge →",
  nudge_up         = "Nudge ↑",
  nudge_down       = "Nudge ↓",
  wider            = "Wider",
  narrower         = "Narrower",
  taller           = "Taller",
  shorter          = "Shorter",
  save_layout      = "Save Layout",
  restore_layout   = "Restore Layout",
  cheatsheet       = "This Cheatsheet",
  send_prev_screen = "← Prev Screen",
  send_next_screen = "Next Screen →",
}

local function display_name(name)
  if LABEL[name] then return LABEL[name] end
  local n = name:match("^send_to_screen_(%d+)$")
  if n then return "Screen " .. n end
  -- fallback: title-case underscore-separated words
  return (name:gsub("_", " ")
              :gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

-- ── Categorisation ───────────────────────────────────────────────────────────

local CATS = {
  "Halves", "Quadrants", "Center / Max",
  "Thirds", "Nudge",     "Resize",
  "3×3 Grid", "Screen",  "Layout",
}

local NAME_CAT = {
  left_half="Halves",       right_half="Halves",
  top_half="Halves",        bottom_half="Halves",
  quadrant_nw="Quadrants",  quadrant_ne="Quadrants",
  quadrant_sw="Quadrants",  quadrant_se="Quadrants",
  maximize="Center / Max",  center="Center / Max",
  third_left="Thirds",      third_center="Thirds",
  third_right="Thirds",     two_thirds_left="Thirds",
  two_thirds_right="Thirds",
  nudge_left="Nudge",       nudge_right="Nudge",
  nudge_up="Nudge",         nudge_down="Nudge",
  wider="Resize",           narrower="Resize",
  taller="Resize",          shorter="Resize",
  save_layout="Layout",     restore_layout="Layout",
  cheatsheet="Layout",
  send_prev_screen="Screen", send_next_screen="Screen",
}

local function categorize(bindings)
  local cats = {}
  for _, c in ipairs(CATS) do cats[c] = {} end

  for _, b in ipairs(bindings) do
    local cat = NAME_CAT[b.name]
    if not cat then
      if     b.name:match("^grid3x3_")       then cat = "3×3 Grid"
      elseif b.name:match("^send_to_screen_") then cat = "Screen"
      end
    end
    if cat then
      cats[cat] = cats[cat] or {}
      table.insert(cats[cat], b)
    end
  end
  return cats
end

-- ── HTML / CSS ───────────────────────────────────────────────────────────────

local CSS = [[
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  background: #1c1c1e;
  color: #d4d4d4;
  font: 13px/1.45 -apple-system, "Helvetica Neue", sans-serif;
  padding: 16px 20px 14px;
}
h1 {
  font-size: 14px; font-weight: 600; color: #f5f5f7;
  margin-bottom: 14px; letter-spacing: .2px;
}
.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px 22px;
  align-items: start;
}
.sec h2 {
  font-size: 9px; font-weight: 700; text-transform: uppercase;
  letter-spacing: 1.1px; color: #48484a;
  border-bottom: 1px solid #2c2c2e;
  padding-bottom: 4px; margin-bottom: 6px;
}
.row {
  display: flex; justify-content: space-between;
  align-items: center; padding: 2px 0; min-height: 20px;
}
.lbl { color: #aeaeb2; font-size: 12px; }
.key {
  font: 600 11px/1 "SF Mono", Menlo, monospace;
  color: #ffd60a;
  background: #2c2c2e;
  padding: 2px 5px; border-radius: 4px;
  white-space: nowrap; letter-spacing: .5px;
}
.foot {
  margin-top: 14px;
  font-size: 11px; color: #3a3a3c;
  text-align: center;
}
]]

local function esc(s)
  return (s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
end

local function build_html(bindings, dismiss_combo)
  local cats = categorize(bindings)
  local t = {}
  local function p(s) t[#t+1] = s end

  p('<!DOCTYPE html><html><head><meta charset="utf-8"><title>Hotkeys</title>')
  p('<style>'..CSS..'</style></head><body>')
  p('<h1>&#9000;&#xFE0E;&nbsp; Hotkey Cheatsheet</h1>')
  p('<div class="grid">')

  for _, cname in ipairs(CATS) do
    local entries = cats[cname]
    if entries and #entries > 0 then
      p('<div class="sec"><h2>'..esc(cname)..'</h2>')

      if cname == "3×3 Grid" then
        -- Collapse all 9 cells into a single summary row.
        local prefix = fmt_mods(entries[1].mods)
        p('<div class="row">'..
          '<span class="lbl">Cell 1–9</span>'..
          '<span class="key">'..esc(prefix)..'1–9</span>'..
          '</div>')
      else
        for _, b in ipairs(entries) do
          p('<div class="row">'..
            '<span class="lbl">'..esc(display_name(b.name))..'</span>'..
            '<span class="key">'..esc(fmt_combo(b))..'</span>'..
            '</div>')
        end
      end

      p('</div>')
    end
  end

  p('</div>')
  p('<div class="foot">Press Esc or '..esc(dismiss_combo)..
    ' to dismiss &nbsp;·&nbsp; or click ✕</div>')
  p('</body></html>')
  return table.concat(t, "\n")
end

-- ── Public API ───────────────────────────────────────────────────────────────

local function close_panel()
  if _esc then _esc:delete(); _esc = nil end
  if _view then pcall(function() _view:delete() end); _view = nil end
end

--- Toggle the cheatsheet panel.
-- @param bindings  Full binding list (from hotkeys_mod.build + extras).
-- @param hyper_mods  Modifier table used for the dismiss-combo label.
function M.toggle(bindings, hyper_mods)
  local dismiss_combo = fmt_mods(hyper_mods or { "ctrl", "alt", "cmd" }) .. "/"

  if _view then
    local ok, vis = pcall(function() return _view:isVisible() end)
    if ok and vis then
      close_panel()
      return
    end
    close_panel()
  end

  -- ── Open the panel ──────────────────────────────────────────────────────
  local sf   = hs.screen.mainScreen():frame()
  local W, H = 820, 510
  local rect = {
    x = sf.x + math.floor((sf.w - W) / 2),
    y = sf.y + math.floor((sf.h - H) / 2),
    w = W, h = H,
  }

  _view = hs.webview.new(rect)

  -- Decorated window (title bar + close button) without stealing focus.
  local wm = hs.webview.windowMasks
  if wm and wm.titled and wm.closable then
    _view:windowStyle(wm.titled + wm.closable)
  end

  _view:level(hs.drawing.windowLevels.floating)
  _view:html(build_html(bindings, dismiss_combo))
  _view:show()

  -- Esc to dismiss.
  _esc = hs.hotkey.bind({}, "escape", function() close_panel() end)
end

return M
