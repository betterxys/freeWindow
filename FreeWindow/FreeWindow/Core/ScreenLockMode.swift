// ScreenLockMode.swift — How the controller should "put the screen off"
// at a work-phase boundary. The actual implementation lives in
// `Services/ScreenLockService.swift` (which depends on AppKit); this
// enum lives in Core so the pure controller and tests can refer to it
// without pulling in the Services layer.

import Foundation

public enum ScreenLockMode: String, Codable {
    /// Turn the display(s) off but keep the session running. Move the
    /// mouse / press a key to come back exactly where you left off.
    /// Implementation: shell out to `/usr/bin/pmset displaysleepnow`.
    case displaysSleep = "displays_sleep"

    /// Engage the lock screen — requires the password to come back.
    /// Implementation: post the standard ⌃⌘Q keystroke via NSAppleScript.
    case lockScreen = "lock_screen"
}
