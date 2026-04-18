-- Shared test helper. Busted auto-requires this via `.busted`.
--
-- It puts `modules/` and `spec/fakes/` on package.path and installs the
-- Hammerspoon fake as the global `hs`, so test files can just
-- `require("init")` or any module as they would on a real Mac.

local here = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
-- Turn relative paths into absolute so package.path works regardless of CWD.
if not here:match("^/") then
  local cwd = io.popen("pwd"):read("*l") or "."
  here = cwd .. "/" .. here
end
local repo = here:gsub("/spec/$", "/"):gsub("/spec/?$", "/")
if not repo:match("/$") then repo = repo .. "/" end

package.path = repo .. "?.lua;" .. repo .. "?/init.lua;" ..
               repo .. "spec/fakes/?.lua;" .. package.path

_G.hs = require("hs")

-- Reset the fake before every test file. Individual specs may call
-- hs._reset() again between test cases if they need isolation.
_G.hs._reset()

-- Shared fixtures / helpers
local fixtures = {}

--- Canonical three-monitor setup used across scenarios:
--   idx 1: 24" portrait external on the left        (1440 x 2560, x = -1440)
--   idx 2: 14" built-in (primary)                   (1512 x 982, x = 0)
--   idx 3: 32" 4K external on the right             (3840 x 2160, x = 1512)
function fixtures.three_monitors()
  return {
    { id = 1001, name = "Left Portrait",        frame = { x = -1440, y = 0,    w = 1440, h = 2560 } },
    { id = 1002, name = "Built-in Retina Display", frame = { x = 0,  y = 0,    w = 1512, h = 982  } },
    { id = 1003, name = "Right 4K",             frame = { x = 1512, y = -589, w = 3840, h = 2160 } },
  }
end

--- Single-monitor setup (laptop only).
function fixtures.laptop_only()
  return {
    { id = 1002, name = "Built-in Retina Display", frame = { x = 0, y = 0, w = 1512, h = 982 } },
  }
end

function fixtures.two_monitors_horizontal()
  return {
    { id = 2001, name = "Built-in Retina Display", frame = { x = 0,    y = 0, w = 1512, h = 982  } },
    { id = 2002, name = "External 27",             frame = { x = 1512, y = 0, w = 2560, h = 1440 } },
  }
end

_G.FIXTURES = fixtures

return fixtures
