#!/usr/bin/env swift
// e2e-window-cross-screen.swift — Verify FreeWindow can move a real window across displays.

import AppKit
import ApplicationServices

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func fail(_ message: String) throws -> Never {
    throw TestFailure(description: message)
}

func postHotkey(virtualKey: CGKeyCode, shift: Bool = false) {
    let flags: CGEventFlags = shift
        ? [.maskControl, .maskAlternate, .maskCommand, .maskShift]
        : [.maskControl, .maskAlternate, .maskCommand]
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: true)!
    down.flags = flags
    let up = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: false)!
    up.flags = flags
    down.post(tap: .cgSessionEventTap)
    up.post(tap: .cgSessionEventTap)
}

func axValue(_ element: AXUIElement, _ attr: String) -> AnyObject? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else {
        return nil
    }
    return value
}

func focusedWindow() throws -> AXUIElement {
    guard let appValue = axValue(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute) else {
        try fail("No focused application")
    }
    let app = appValue as! AXUIElement
    guard let winValue = axValue(app, kAXFocusedWindowAttribute) else {
        try fail("No focused window")
    }
    return winValue as! AXUIElement
}

func textEditWindow() throws -> AXUIElement {
    guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.TextEdit" }) else {
        try fail("TextEdit is not running")
    }
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    if let focused = axValue(appElement, kAXFocusedWindowAttribute) {
        return focused as! AXUIElement
    }
    guard let windows = axValue(appElement, kAXWindowsAttribute) as? [AXUIElement],
          let first = windows.first else {
        try fail("No TextEdit windows")
    }
    return first
}

func rect(of window: AXUIElement) throws -> CGRect {
    guard let posObject = axValue(window, kAXPositionAttribute),
          let sizeObject = axValue(window, kAXSizeAttribute) else {
        try fail("Could not read focused window frame")
    }
    let posValue = posObject as! AXValue
    let sizeValue = sizeObject as! AXValue
    var pos = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(posValue, .cgPoint, &pos)
    AXValueGetValue(sizeValue, .cgSize, &size)
    return CGRect(origin: pos, size: size)
}

func screenIndex(for rect: CGRect, screens: [NSScreen]) -> Int? {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    return screens.firstIndex { axVisibleFrame(for: $0).contains(center) }
}

func axVisibleFrame(for screen: NSScreen) -> CGRect {
    guard let primary = NSScreen.screens.first else { return screen.visibleFrame }
    let visible = screen.visibleFrame
    let topLeftY = primary.frame.height - visible.origin.y - visible.height
    return CGRect(
        x: visible.origin.x,
        y: topLeftY,
        width: visible.width,
        height: visible.height
    )
}

func waitForWindowOnScreen(_ target: Int, screens: [NSScreen], timeout: TimeInterval = 4) throws -> CGRect {
    let deadline = Date().addingTimeInterval(timeout)
    var latest: CGRect = .zero
    while Date() < deadline {
        latest = try rect(of: textEditWindow())
        if screenIndex(for: latest, screens: screens) == target {
            return latest
        }
        Thread.sleep(forTimeInterval: 0.2)
    }
    try fail("Window did not move to screen \(target); last frame \(latest)")
}

func keyCodeForNumber(_ n: Int) -> CGKeyCode {
    switch n {
    case 1: return 0x12
    case 2: return 0x13
    case 3: return 0x14
    default: return 0x12
    }
}

func approximatelyEqual(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 4) -> Bool {
    abs(a - b) <= tolerance
}

func freeWindowScreenOrder(_ screens: [NSScreen]) -> [Int] {
    screens.indices.sorted {
        let a = screens[$0].frame
        let b = screens[$1].frame
        if a.minX != b.minX { return a.minX < b.minX }
        return a.minY < b.minY
    }
}

do {
    print("═══════════════════════════════════════════════")
    print("  FreeWindow E2E — Cross-Screen Window Move")
    print("═══════════════════════════════════════════════")

    guard AXIsProcessTrusted() else {
        try fail("This test runner lacks Accessibility permission")
    }
    guard NSScreen.screens.count >= 2 else {
        try fail("Need at least two screens; found \(NSScreen.screens.count)")
    }
    guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleURL?.lastPathComponent == "FreeWindow.app" }) else {
        try fail("FreeWindow is not running")
    }

    let screens = NSScreen.screens
    for (index, screen) in screens.enumerated() {
        print("  screen \(index): frame=\(screen.frame), axVisible=\(axVisibleFrame(for: screen))")
    }

    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
                                       configuration: NSWorkspace.OpenConfiguration()) { _, error in
        if let error {
            print("TextEdit launch warning: \(error)")
        }
    }
    Thread.sleep(forTimeInterval: 1.5)

    let script = """
    tell application "TextEdit"
        activate
        make new document
    end tell
    """
    var error: NSDictionary?
    NSAppleScript(source: script)?.executeAndReturnError(&error)
    if let error {
        try fail("Could not create TextEdit test window: \(error)")
    }
    Thread.sleep(forTimeInterval: 1.0)

    let window = try textEditWindow()
    let start = try rect(of: window)
    guard let startScreen = screenIndex(for: start, screens: screens) else {
        try fail("Focused TextEdit window is not on a known screen: \(start)")
    }
    print("  start: screen \(startScreen), frame=\(start)")

    postHotkey(virtualKey: 0x04) // H = left half
    Thread.sleep(forTimeInterval: 1.0)
    let leftHalf = try rect(of: textEditWindow())
    let currentVisible = axVisibleFrame(for: screens[startScreen])
    if approximatelyEqual(leftHalf.minX, currentVisible.minX),
       approximatelyEqual(leftHalf.width, currentVisible.width / 2) {
        print("  left half: frame=\(leftHalf)")
    } else {
        try fail("Same-screen left-half hotkey did not move window; frame \(leftHalf), expected screen visible \(currentVisible)")
    }

    let order = freeWindowScreenOrder(screens)
    guard let startOrder = order.firstIndex(of: startScreen) else {
        try fail("Could not map start screen to FreeWindow screen order")
    }
    let targetOrder = startOrder == 0 ? 1 : 0
    let target = order[targetOrder]
    postHotkey(virtualKey: keyCodeForNumber(targetOrder + 1))
    let moved = try waitForWindowOnScreen(target, screens: screens)
    print("  moved: screen \(target), frame=\(moved)")

    postHotkey(virtualKey: keyCodeForNumber(startOrder + 1))
    let restored = try waitForWindowOnScreen(startScreen, screens: screens)
    print("  restored: screen \(startScreen), frame=\(restored)")

    NSAppleScript(source: """
    tell application "TextEdit"
        close front document saving no
    end tell
    """)?.executeAndReturnError(nil)

    print("  ✅ Cross-screen window move works")
    print("═══════════════════════════════════════════════")
    exit(0)
} catch {
    print("  ❌ \(error)")
    print("═══════════════════════════════════════════════")
    exit(1)
}
