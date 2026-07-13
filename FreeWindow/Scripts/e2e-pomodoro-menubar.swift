#!/usr/bin/env swift
// e2e-pomodoro-menubar.swift — End-to-end test for menu bar pomodoro timer.
// Requires: FreeWindow running, Terminal/Cursor with Accessibility permission.

import Cocoa
import ApplicationServices

var failures: [String] = []
var passes = 0

func pass(_ msg: String) { passes += 1; print("  ✅ \(msg)") }
func fail(_ msg: String) { failures.append(msg); print("  ❌ \(msg)") }

func postHotkey(virtualKey: CGKeyCode, flags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]) {
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: true)!
    down.flags = flags
    let up = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: false)!
    up.flags = flags
    down.post(tap: .cgSessionEventTap)
    up.post(tap: .cgSessionEventTap)
}

func freeWindowPID() -> pid_t? {
    NSWorkspace.shared.runningApplications
        .first { $0.bundleURL?.lastPathComponent == "FreeWindow.app" }?
        .processIdentifier
}

func axString(_ element: AXUIElement, _ attr: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success,
          let v = value else { return nil }
    if let s = v as? String { return s }
    if let a = v as? [String] { return a.joined(separator: " ") }
    return nil
}

func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
          let arr = value as? [AXUIElement] else { return [] }
    return arr
}

func collectTexts(_ element: AXUIElement, depth: Int = 0) -> [String] {
    guard depth < 12 else { return [] }
    var out: [String] = []
    for key in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXRoleDescriptionAttribute] {
        if let t = axString(element, key as String), !t.isEmpty { out.append(t) }
    }
    for child in axChildren(element) {
        out.append(contentsOf: collectTexts(child, depth: depth + 1))
    }
    return out
}

func findMenuBarTimerTexts(pid: pid_t) -> [String] {
    let app = AXUIElementCreateApplication(pid)
    var texts: [String] = []

    var menuBarRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
       let menuBar = menuBarRef {
        texts.append(contentsOf: collectTexts(menuBar as! AXUIElement))
    }

    // Status items sometimes live outside the menu bar tree; scan the whole app AX tree.
    texts.append(contentsOf: collectTexts(app))
    return Array(Set(texts))
}

func timerLabel(in texts: [String]) -> String? {
    let pattern = #"^[⏸🍅☕🛋] \d+:\d{2}$"#
    return texts.first { $0.range(of: pattern, options: .regularExpression) != nil }
}

func readPomodoroLogTail() -> String {
    (try? String(contentsOfFile: "/tmp/freewindow_pomodoro.log", encoding: .utf8)) ?? ""
}

func parseMinutes(_ label: String) -> Int? {
    guard let space = label.firstIndex(of: " ") else { return nil }
    let time = String(label[label.index(after: space)...])
    let parts = time.split(separator: ":")
    guard parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) else { return nil }
    return m * 60 + s
}

print("═══════════════════════════════════════════════")
print("  FreeWindow E2E — Pomodoro Menu Bar")
print("═══════════════════════════════════════════════")

guard let pid = freeWindowPID() else {
    fail("FreeWindow is not running")
    print("\nResult: FAILED")
    exit(1)
}
pass("FreeWindow running (pid \(pid))")

if !AXIsProcessTrusted() {
    fail("This test runner lacks Accessibility permission — enable it in System Settings")
}

// Ensure clean idle state
print("\n[1] Cancel any in-flight pomodoro")
postHotkey(virtualKey: 0x07) // X
Thread.sleep(forTimeInterval: 0.8)

let idleTexts = findMenuBarTimerTexts(pid: pid)
if timerLabel(in: idleTexts) != nil {
    fail("Expected no timer label while idle, found: \(idleTexts)")
} else {
    pass("Idle state shows no timer label")
}

print("\n[2] Start pomodoro (⌃⇧S)")
let logBefore = readPomodoroLogTail()
postHotkey(virtualKey: 0x01, flags: [.maskControl, .maskShift]) // S
Thread.sleep(forTimeInterval: 1.0)

let startedTexts = findMenuBarTimerTexts(pid: pid)
if let startLabel = timerLabel(in: startedTexts) {
    pass("Menu bar shows timer: \(startLabel)")
    if startLabel.hasPrefix("🍅") {
        pass("Work phase emoji correct")
    } else {
        fail("Expected work phase label, got \(startLabel)")
    }
    if let secs = parseMinutes(startLabel), secs >= 24 * 60 {
        pass("Initial remaining time looks like a full work phase (\(secs)s)")
    } else {
        fail("Unexpected initial remaining time in \(startLabel)")
    }
} else {
    fail("Menu bar timer not found after start. AX texts: \(Array(startedTexts.prefix(20)))")
    let logAfter = readPomodoroLogTail()
    if logAfter != logBefore {
        pass("Pomodoro log updated (hotkey reached app)")
    }
}

print("\n[3] Countdown ticks")
let label1 = timerLabel(in: findMenuBarTimerTexts(pid: pid))
Thread.sleep(forTimeInterval: 2.5)
let label2 = timerLabel(in: findMenuBarTimerTexts(pid: pid))
if let a = label1, let b = label2, let s1 = parseMinutes(a), let s2 = parseMinutes(b), s2 < s1 {
    pass("Timer decreased: \(a) → \(b)")
} else {
    fail("Timer did not decrease (\(label1 ?? "nil") → \(label2 ?? "nil"))")
}

print("\n[4] Pause (⌃⇧S)")
postHotkey(virtualKey: 0x01, flags: [.maskControl, .maskShift]) // S
Thread.sleep(forTimeInterval: 0.8)
let pausedLabel = timerLabel(in: findMenuBarTimerTexts(pid: pid))
if let p = pausedLabel, p.hasPrefix("⏸") {
    pass("Paused label shown: \(p)")
} else {
    fail("Expected paused label, got \(pausedLabel ?? "nil")")
}

let frozen = pausedLabel
Thread.sleep(forTimeInterval: 2.0)
let still = timerLabel(in: findMenuBarTimerTexts(pid: pid))
if frozen == still {
    pass("Paused timer stays frozen: \(still ?? "nil")")
} else {
    fail("Paused timer changed: \(frozen ?? "nil") → \(still ?? "nil")")
}

print("\n[5] Cancel (⌃⌥⌘⇧X)")
postHotkey(virtualKey: 0x07)
Thread.sleep(forTimeInterval: 0.8)
if timerLabel(in: findMenuBarTimerTexts(pid: pid)) == nil {
    pass("Timer label cleared after cancel")
} else {
    fail("Timer label still visible after cancel")
}

let logTail = readPomodoroLogTail()
if logTail.contains("transition=started") {
    pass("Pomodoro log records start transition")
} else {
    fail("Pomodoro log missing start transition")
}

print("\n═══════════════════════════════════════════════")
if failures.isEmpty {
    print("  ✅ E2E passed (\(passes) checks)")
} else {
    print("  ❌ E2E failed (\(failures.count) failures, \(passes) passes)")
    for f in failures { print("     • \(f)") }
}
print("═══════════════════════════════════════════════\n")
exit(failures.isEmpty ? 0 : 1)
