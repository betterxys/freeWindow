// ScreenLockService.swift — Put the display to sleep or lock the screen.
// Swift port of `driver.put_screen_off` from the Lua codebase.
//
// `ScreenLockMode` lives in `FreeWindowCore` (Core/ScreenLockMode.swift)
// so the pure controller can refer to it without pulling in AppKit.

import Foundation
import AppKit
import FreeWindowCore

public final class ScreenLockService {
    public static let shared = ScreenLockService()

    /// Test seam: when set, `apply` calls this instead of touching the
    /// real system. Returns true if accepted, false otherwise.
    public var override: ((ScreenLockMode) -> Bool)?

    public init() {}

    /// Apply the requested mode. Returns true if the action ran.
    @discardableResult
    public func apply(_ mode: ScreenLockMode) -> Bool {
        appendLog("[ScreenLockService] apply mode=\(mode.rawValue)")
        if let override { return override(mode) }
        // Diagnostic dry-run: when the file `/tmp/freewindow_no_lock` exists
        // we skip the real action and just log. Useful for "do the real
        // thing except actually lock" smoke tests; not tied to release
        // builds because anyone debugging a stuck pomodoro will need it.
        if FileManager.default.fileExists(atPath: "/tmp/freewindow_no_lock") {
            appendLog("[ScreenLockService] DRY_RUN — /tmp/freewindow_no_lock exists, skipping real action")
            return true
        }
        switch mode {
        case .displaysSleep:
            return runShell("/usr/bin/pmset", args: ["displaysleepnow"])
        case .lockScreen:
            return runAppleScript("""
            tell application "System Events" to keystroke "q" using {control down, command down}
            """)
        }
    }

    private func appendLog(_ msg: String) {
        let line = msg + "\n"
        let path = "/tmp/freewindow_pomodoro.log"
        if let data = line.data(using: .utf8) {
            if let fh = FileHandle(forWritingAtPath: path) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            } else {
                FileManager.default.createFile(atPath: path, contents: data)
            }
        }
    }

    @discardableResult
    private func runShell(_ path: String, args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            // Don't waitUntilExit — pmset returns near-instantly but if a
            // user-level fault made it hang we don't want to freeze the
            // hotkey thread. The OS reaps it.
            return true
        } catch {
            NSLog("[ScreenLockService] %@ failed: %@", path, "\(error)")
            return false
        }
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> Bool {
        var err: NSDictionary?
        if let script = NSAppleScript(source: source) {
            script.executeAndReturnError(&err)
            if err != nil {
                NSLog("[ScreenLockService] AppleScript error: %@", "\(err!)")
                return false
            }
            return true
        }
        return false
    }
}
