-- Static analysis config for the Hammerspoon window manager config.
--
-- Notes:
--   * `hs` is the global Hammerspoon namespace, available at runtime on macOS
--     and provided by our fake module (spec/fakes/hs.lua) under tests.
--   * We use `require` with package-relative paths rooted at repo root, so no
--     globals leak between modules.

std = "lua54"
max_line_length = 120
codes = true

-- Treat the Hammerspoon runtime namespace as a read-only global.
read_globals = {
  "hs",
}

-- Busted test DSL injects these as globals.
files["spec/"] = {
  std = "+busted",
  read_globals = {
    "describe", "it", "before_each", "after_each", "setup", "teardown",
    "pending", "finally", "assert", "spy", "stub", "mock",
    "FIXTURES",
  },
}

-- The hs fake deliberately defines a table named `hs` for tests.
files["spec/fakes/hs.lua"] = {
  globals = { "hs" },
}

-- The init entrypoint exists on macOS only; skip some warnings there.
files["init.lua"] = {
  ignore = { "212" }, -- unused argument
}

exclude_files = {
  ".luarocks/",
  "lua_modules/",
}
