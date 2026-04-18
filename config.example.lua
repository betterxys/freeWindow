-- Example local config. Copy to `config.lua` (git-ignored) on your Mac and
-- tweak. Everything here is optional; missing keys fall back to defaults.

return {
  -- Prefix keys. The defaults are ⌃⌥⌘ (hyper) and ⌃⌥⌘⇧ (hyper-shift).
  -- Example to use "caps lock as hyper" via Karabiner, leave the defaults.
  -- hyper       = { "ctrl", "alt", "cmd" },
  -- hyper_shift = { "ctrl", "alt", "cmd", "shift" },

  -- Friendly names for physical screens. The values are either a 1-based
  -- position in left→right order, or the macOS display name as returned
  -- by `hs.screen:name()`.
  --
  -- These roles can be referenced from actions.send_to_role(...). They are
  -- not bound to hotkeys by default; add your own bindings in init.lua if
  -- you want shortcuts like "send to the left external".
  role_map = {
    -- main  = "Built-in Retina Display",
    -- left  = 1,
    -- right = 3,
  },

  -- Nudge / resize grid density.
  grid = { cols = 12, rows = 8 },

  -- Where named layouts are stored.
  -- layouts_dir = os.getenv("HOME") .. "/.hammerspoon/layouts",
}
