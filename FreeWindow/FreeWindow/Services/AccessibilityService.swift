import FreeWindowCore
// AccessibilityService.swift — AXUIElement wrappers for window management.
// Provides: focused window, visible windows, get/set frame, window properties.

import AppKit
import ApplicationServices

/// Represents a window handle via AXUIElement.
struct AXWindow {
    let element: AXUIElement
    let pid: pid_t

    var frame: WMRect? {
        guard let pos = getPosition(), let size = getSize() else { return nil }
        return WMRect(x: Int(pos.x), y: Int(pos.y), w: Int(size.width), h: Int(size.height))
    }

    var title: String? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
        return value as? String
    }

    var appName: String? {
        let app = NSRunningApplication(processIdentifier: pid)
        return app?.localizedName
    }

    var isStandard: Bool {
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        guard (role as? String) == kAXWindowRole else { return false }
        var subrole: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        return (subrole as? String) == kAXStandardWindowSubrole
    }

    var isMinimized: Bool {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value)
        return (value as? Bool) ?? false
    }

    /// Get the CGWindowID by matching this AX window against the public
    /// CoreGraphics on-screen window list.
    var windowId: CGWindowID? {
        guard let pos = getPosition(), let size = getSize() else { return nil }
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in windowList {
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let wid = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            let wx = bounds["X"] ?? 0
            let wy = bounds["Y"] ?? 0
            let ww = bounds["Width"] ?? 0
            let wh = bounds["Height"] ?? 0
            if abs(wx - pos.x) < 2 && abs(wy - pos.y) < 2 &&
               abs(ww - size.width) < 2 && abs(wh - size.height) < 2 {
                return wid
            }
        }
        return nil
    }

    // MARK: - Position/Size

    private func getPosition() -> CGPoint? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)
        guard err == .success, let axValue = value else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return point
    }

    private func getSize() -> CGSize? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)
        guard err == .success, let axValue = value else { return nil }
        var size = CGSize.zero
        AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return size
    }

    func setFrame(_ rect: WMRect) {
        // Set position first, then size (order matters for some apps)
        var point = CGPoint(x: CGFloat(rect.x), y: CGFloat(rect.y))
        if let posValue = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)
        }
        var size = CGSize(width: CGFloat(rect.w), height: CGFloat(rect.h))
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        }
        // Set position again (some apps adjust position after resize)
        if let posValue = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)
        }
    }
}

/// Service for accessing windows via Accessibility API.
final class AccessibilityService {

    static let shared = AccessibilityService()

    /// Check if we have accessibility permission.
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Get the focused window of the frontmost application.
    func focusedWindow() -> AXWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedValue: AnyObject?
        let err = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedValue)
        guard err == .success, let windowElement = focusedValue else { return nil }

        return AXWindow(element: windowElement as! AXUIElement, pid: pid)
    }

    /// Get all visible, standard, non-minimized windows across all apps.
    func visibleWindows() -> [AXWindow] {
        var result: [AXWindow] = []
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        for app in apps {
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)

            var windowsValue: AnyObject?
            let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
            guard err == .success, let windows = windowsValue as? [AXUIElement] else { continue }

            for winElement in windows {
                let win = AXWindow(element: winElement, pid: pid)
                if win.isStandard && !win.isMinimized {
                    result.append(win)
                }
            }
        }

        return result
    }
}
