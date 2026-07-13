#!/usr/bin/env swift
// Real UI E2E for the three work-complete choices.
// Run with short durations in ~/.freewindow/config.json.

import AppKit
import ApplicationServices

var failures: [String] = []
var passes = 0

func pass(_ message: String) { passes += 1; print("  ✅ \(message)") }
func fail(_ message: String) { failures.append(message); print("  ❌ \(message)") }

func postHotkey(key: CGKeyCode, flags: CGEventFlags) {
    let source = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)!
    down.flags = flags
    let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)!
    up.flags = flags
    down.post(tap: .cgSessionEventTap)
    up.post(tap: .cgSessionEventTap)
}

func togglePomodoro() {
    postHotkey(key: 0x01, flags: [.maskControl, .maskShift]) // S
}

func cancelPomodoro() {
    postHotkey(key: 0x07, flags: [.maskControl, .maskAlternate, .maskCommand, .maskShift]) // X
}

func freeWindowPID() -> pid_t? {
    NSWorkspace.shared.runningApplications
        .first { $0.bundleURL?.lastPathComponent == "FreeWindow.app" }?
        .processIdentifier
}

func axValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
        return nil
    }
    return value
}

func axString(_ element: AXUIElement, _ attribute: String) -> String? {
    axValue(element, attribute) as? String
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    axValue(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func allElements(_ root: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 16 else { return [root] }
    return [root] + children(root).flatMap { allElements($0, depth: depth + 1) }
}

func onscreenWindowBounds(pid: pid_t) -> [CGRect] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    return list.compactMap { window in
        guard (window[kCGWindowOwnerPID as String] as? Int32) == pid,
              let boundsObject = window[kCGWindowBounds as String] else {
            return nil
        }
        return CGRect(dictionaryRepresentation: boundsObject as! CFDictionary)
    }
}

func visiblePanelBounds(pid: pid_t) -> CGRect? {
    onscreenWindowBounds(pid: pid).first {
        $0.width >= 400 && $0.width <= 500 && $0.height >= 350 && $0.height <= 450
    }
}

func waitForPanel(pid: pid_t, timeout: TimeInterval = 8) -> CGRect? {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let panel = visiblePanelBounds(pid: pid) { return panel }
        Thread.sleep(forTimeInterval: 0.2)
    }
    return nil
}

enum ChoiceButton {
    case skip, snooze, takeBreak
}

func pointValue(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
    guard let value = axValue(element, attribute) else { return nil }
    var point = CGPoint.zero
    guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
    return point
}

func sizeValue(_ element: AXUIElement, _ attribute: String) -> CGSize? {
    guard let value = axValue(element, attribute) else { return nil }
    var size = CGSize.zero
    guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
    return size
}

func pressChoice(_ choice: ChoiceButton, panel: CGRect) {
    // PhaseReminderView has a fixed 440×400 panel. Button centers are stable
    // relative to the panel: skip, snooze, take-break from left to right.
    let xOffset: CGFloat
    switch choice {
    case .skip: xOffset = panel.width * 0.295
    case .snooze: xOffset = panel.width * 0.50
    case .takeBreak: xOffset = panel.width * 0.705
    }
    let point = CGPoint(x: panel.minX + xOffset, y: panel.maxY - 14)
    let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

func collectStrings(_ root: AXUIElement) -> [String] {
    allElements(root).flatMap { element in
        [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].compactMap {
            axString(element, $0)
        }
    }
}

func timerLabel(pid: pid_t) -> String? {
    let values = collectStrings(AXUIElementCreateApplication(pid))
    let regex = try! NSRegularExpression(pattern: #"^[⏸🍅☕🛋] \d+:\d{2}$"#)
    return values.first {
        regex.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil
    }
}

func waitForTimer(prefix: String, pid: pid_t, timeout: TimeInterval = 3) -> String? {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let label = timerLabel(pid: pid), label.hasPrefix(prefix) { return label }
        Thread.sleep(forTimeInterval: 0.1)
    }
    return nil
}

func fullscreenBackdropCount(pid: pid_t) -> Int {
    onscreenWindowBounds(pid: pid).filter { $0.width > 1_000 && $0.height > 800 }.count
}

func pomodoroLog() -> String {
    (try? String(contentsOfFile: "/tmp/freewindow_pomodoro.log", encoding: .utf8)) ?? ""
}

func waitForLog(_ marker: String, after snapshot: String, timeout: TimeInterval = 3) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        let current = pomodoroLog()
        if current.count >= snapshot.count,
           String(current.dropFirst(snapshot.count)).contains(marker) {
            return true
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    return false
}

print("═══════════════════════════════════════════════")
print("  FreeWindow E2E — Work-Complete Choices")
print("═══════════════════════════════════════════════")

guard AXIsProcessTrusted(), let pid = freeWindowPID() else {
    print("  ❌ Test runner lacks AX permission or FreeWindow is not running")
    exit(1)
}

cancelPomodoro()
Thread.sleep(forTimeInterval: 0.5)

// 1. Take break: wait as long as we like, then receive the full rest duration.
print("\n[1] 开始休息")
togglePomodoro()
if let panel = waitForPanel(pid: pid) {
    Thread.sleep(forTimeInterval: 1.5) // countdown reaches zero
    let count = fullscreenBackdropCount(pid: pid)
    if count == 0 { pass("倒计时结束后灰色全屏遮罩已移除") }
    else { fail("倒计时结束后仍有 \(count) 个全屏遮罩") }
    let before = pomodoroLog()
    pressChoice(.takeBreak, panel: visiblePanelBounds(pid: pid) ?? panel)
    if waitForLog("finishLock -> takeBreak", after: before) {
        pass("“开始休息”按钮触发 takeBreak")
    } else {
        fail("“开始休息”没有触发 takeBreak")
    }
    if let label = waitForTimer(prefix: "☕", pid: pid) {
        pass("开始休息后进入完整休息计时：\(label)")
    } else {
        fail("点击开始休息后没有进入休息阶段")
    }
} else {
    fail("未找到“开始休息”按钮")
}
cancelPomodoro()
Thread.sleep(forTimeInterval: 0.5)

// 2. Snooze: return to a short work extension, then ask again.
print("\n[2] 推迟")
togglePomodoro()
if let panel = waitForPanel(pid: pid) {
    let before = pomodoroLog()
    pressChoice(.snooze, panel: panel)
    if waitForLog("finishLock -> snooze", after: before) {
        pass("“推迟”按钮触发 snooze")
    } else {
        fail("“推迟”没有触发 snooze")
    }
    if let label = waitForTimer(prefix: "🍅", pid: pid) {
        pass("推迟后回到工作延长计时：\(label)")
    } else {
        fail("点击推迟后没有回到工作阶段")
    }
    if waitForPanel(pid: pid, timeout: 5) != nil {
        pass("推迟到期后重新询问")
    } else {
        fail("推迟到期后没有重新弹出选择")
    }
} else {
    fail("未找到“推迟”按钮")
}
cancelPomodoro()
Thread.sleep(forTimeInterval: 0.5)

// 3. Skip: bypass rest and start the next full work period.
print("\n[3] 跳过一次")
togglePomodoro()
if let panel = waitForPanel(pid: pid) {
    let before = pomodoroLog()
    pressChoice(.skip, panel: panel)
    if waitForLog("finishLock -> skipped", after: before) {
        pass("“跳过一次”按钮触发 skip")
    } else {
        fail("“跳过一次”没有触发 skip")
    }
    if let label = waitForTimer(prefix: "🍅", pid: pid) {
        pass("跳过后进入下一工作周期：\(label)")
    } else {
        fail("点击跳过后没有进入下一工作周期")
    }
    if visiblePanelBounds(pid: pid) == nil {
        pass("跳过后选择弹窗已关闭")
    } else {
        fail("跳过后选择弹窗仍存在")
    }
} else {
    fail("未找到“跳过一次”按钮")
}
cancelPomodoro()

print("\n═══════════════════════════════════════════════")
if failures.isEmpty {
    print("  ✅ E2E passed (\(passes) checks)")
} else {
    print("  ❌ E2E failed (\(failures.count) failures, \(passes) passes)")
    failures.forEach { print("     • \($0)") }
}
print("═══════════════════════════════════════════════")
exit(failures.isEmpty ? 0 : 1)
