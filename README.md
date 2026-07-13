# FreeWindow

FreeWindow is a native macOS menu-bar productivity app:

- window placement, resize, layouts, and cross-display movement;
- clipboard history for text, rich text, images, and files;
- region screenshots pinned as floating reference windows;
- a Pomodoro timer with context-aware break reminders;
- bundled [Ice](https://github.com/jordanbaird/Ice) for menu-bar overflow management.

It is built with Swift, AppKit, SwiftUI, Carbon hotkeys, and Accessibility APIs.
There is no Hammerspoon, Electron, or runtime dependency.

## Install

Requirements: macOS 13 or later. Ice's advanced menu-bar features require
macOS 14 or later.

Build the app and DMG:

```bash
cd FreeWindow
./Scripts/build-dmg.sh
open build/FreeWindow-1.2.0.dmg
```

Or build and install directly:

```bash
./Scripts/build-dmg.sh && ./Scripts/install.sh
```

The installer only installs Ice when `/Applications/Ice.app` is missing.
Existing Ice installations are never overwritten, preserving their permissions
and settings.

### Permissions

Enable **FreeWindow** in:

`System Settings → Privacy & Security → Accessibility`

This is required for moving and resizing other apps' windows. Screenshot
capture may also prompt for Screen Recording access.

For stable Accessibility permission across local rebuilds, run once:

```bash
./Scripts/setup-signing.sh
```

If no identity exists, create a trusted self-use identity:

```bash
./Scripts/create-local-signing-cert.sh
```

Public distribution requires an Apple Developer Program `Developer ID
Application` certificate and notarization; the local certificate is for this
Mac only.

## Hotkeys

`Hyper` = `⌃⌥⌘`; `Hyper Shift` = `⌃⌥⌘⇧`.

### Window management

| Shortcut | Action |
|---|---|
| `Hyper + H / L / K / J` | Left / right / top / bottom half |
| `Hyper + U / I / N / M` | Four quadrants |
| `Hyper + Return` | Maximize |
| `Hyper + C` | Center without resizing |
| `Hyper Shift + H / J / L` | Left / center / right third |
| `Hyper Shift + U / O` | Left / right two-thirds |
| `Hyper Shift + 1…9` | 3×3 grid |
| `Hyper + ← / → / ↑ / ↓` | Nudge one grid step |
| `Hyper + ] / [` | Wider / narrower |
| `Hyper Shift + ] / [` | Taller / shorter |
| `Hyper + 1 / 2 / 3` | Send to display 1 / 2 / 3 |
| `Hyper + . / ,` | Next / previous display |
| `Hyper + S / R` | Save / restore the default layout |
| `Hyper + /` | Toggle shortcut cheatsheet |

Displays are ordered left-to-right by physical position. The saved layout is
stored at `~/.freewindow/layouts/default.json`.

### Clipboard and screenshot

| Shortcut | Action |
|---|---|
| `Hyper + V` | Toggle clipboard history |
| `Hyper + P` | Select a region and pin the screenshot |
| `Hyper Shift + P` | Remove all screenshot pins |

### Pomodoro

| Shortcut | Action |
|---|---|
| `⌃⇧S` | Start / pause / resume |
| `Hyper Shift + .` | Skip the current phase |
| `Hyper Shift + X` | Cancel |
| `Hyper Shift + /` | Show current status |

Defaults: 25 minutes work, 5 minutes short rest, and a 15-minute long rest
after every four work cycles.

At the end of work, the timer freezes while the user chooses:

- **Start break** — starts the full break from the click;
- **Snooze** — continues work for the configured delay, then asks again;
- **Skip once** — skips the break and starts the next full work period.

The gray full-screen backdrop is removed when the warning countdown reaches
zero; the choice panel remains until the user acts. Any timer command also
clears a stale reminder.

Break discipline:

- `gentle` (default): reminder only, never sleeps the display;
- `firm`: reserved for stronger skip limits;
- `strict`: the confirmed break can sleep or lock the screen.

Meeting, screen-sharing, microphone, and display-mirroring signals defer the
work-complete prompt. After the retry limit, FreeWindow asks the user instead
of taking an automatic action.

## Configuration

Copy the example and edit any values you need:

```bash
mkdir -p ~/.freewindow
cp config.example.json ~/.freewindow/config.json
```

Important Pomodoro keys:

```json
{
  "pomodoro": {
    "work_minutes": 25,
    "rest_minutes": 5,
    "long_rest_minutes": 15,
    "cycles_until_long_rest": 4,
    "break_discipline": "gentle",
    "break_snooze_minutes": 5,
    "lock_warning_seconds": 10,
    "lock_action": "displays_sleep",
    "busy_grace_seconds": 60,
    "busy_max_retries": 3
  }
}
```

`lock_action` is `displays_sleep` or `lock_screen`. Custom
`busy_keywords` replace the built-in list.

For a no-sleep test run:

```bash
touch /tmp/freewindow_no_lock
```

Delete that file to re-enable the configured screen action.

## Build and test

```bash
cd FreeWindow
swift build
swift run FreeWindowTestRunner
./Scripts/build-dmg.sh
```

The deterministic test runner currently covers 182 assertions across geometry,
screen ordering, actions, hotkey conflicts, busy detection, and Pomodoro
transitions.

Real-system E2E scripts:

```bash
swift Scripts/e2e-pomodoro-menubar.swift
swift Scripts/e2e-pomodoro-break-options.swift
swift Scripts/e2e-window-cross-screen.swift
```

The E2E scripts require FreeWindow to be running and the invoking terminal to
have Accessibility permission.

## Repository layout

```text
FreeWindow/
├── Package.swift
├── config.example.json
├── FreeWindow/
│   ├── App/            lifecycle, status item, config, permissions
│   ├── Core/           pure geometry, layouts, Pomodoro state machine
│   ├── Features/       window manager, clipboard, screenshot, Pomodoro, help
│   ├── Services/       Accessibility, hotkeys, screens, reminders, locking
│   └── Resources/
├── FreeWindowTests/    deterministic standalone test runner
├── Packaging/          icons and third-party notices
└── Scripts/            build, install, signing, and E2E scripts
```

## Third-party software

The DMG bundles Ice. See `FreeWindow/Packaging/THIRD_PARTY_NOTICES.md` for its
license notice. FreeWindow does not overwrite an already installed Ice app.

## License

[MIT](LICENSE)
