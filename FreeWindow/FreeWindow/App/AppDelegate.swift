import FreeWindowCore
// AppDelegate.swift — Application lifecycle management.
// Handles: accessibility permission check, service initialization, hotkey registration.

import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: WindowManagerCoordinator?
    private var clipboardManager: ClipboardManager?
    private var screenshotPinManager: ScreenshotPinManager?

    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Log startup state
        let axTrusted = AXIsProcessTrusted()
        let startMsg = "[FreeWindow] Launch. AXIsProcessTrusted=\(axTrusted)\n"
        try? startMsg.write(toFile: "/tmp/freewindow_launch.log", atomically: true, encoding: .utf8)

        // Always register notification handlers
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleToggleCheatsheet),
            name: .toggleCheatsheet, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleShowAbout),
            name: .showAbout, object: nil)

        // Start ALL hotkey services unconditionally (Carbon doesn't need AX permission)
        startAllServices()

        // If AX permission available, window management is ready immediately.
        // If not, poll until it becomes available (user toggles switch).
        if !axTrusted {
            startPermissionPolling()
        }
    }

    /// Start everything: hotkeys, clipboard, screenshot, window management.
    private func startAllServices() {
        // Clipboard
        clipboardManager = ClipboardManager()
        clipboardManager?.start()

        // Screenshot
        screenshotPinManager = ScreenshotPinManager()

        // Window management coordinator (registers all hotkeys including window ones)
        coordinator = WindowManagerCoordinator()
        coordinator?.start()

        // Additional hotkeys handled directly by AppDelegate
        // (not registered via coordinator to avoid window management dependency)
        let hotkeyService = HotkeyService.shared
        hotkeyService.register(modifiers: HotkeyBindings.defaultHyper, key: "v") { [weak self] in
            self?.clipboardManager?.togglePopup()
        }
        hotkeyService.register(modifiers: HotkeyBindings.defaultHyper, key: "p") { [weak self] in
            self?.screenshotPinManager?.captureAndPin()
        }
        hotkeyService.register(modifiers: HotkeyBindings.defaultHyperShift, key: "p") { [weak self] in
            self?.screenshotPinManager?.removeAllPins()
        }
    }

    /// Poll until accessibility becomes available (for window movement to work).
    private func startPermissionPolling() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            if AXIsProcessTrusted() {
                self?.permissionTimer?.invalidate()
                self?.permissionTimer = nil
                ToastService.shared.show("✅ Accessibility granted – window management active")
                let log = "[FreeWindow] AX permission acquired\n"
                self?.appendToLog(log)
            }
        }
    }

    private func appendToLog(_ msg: String) {
        let logFile = "/tmp/freewindow_launch.log"
        if let data = msg.data(using: .utf8), let fh = FileHandle(forWritingAtPath: logFile) {
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
        clipboardManager?.stop()
    }

    /// Prevent the app from terminating when the last window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Notifications (always work, no accessibility needed)

    @objc private func handleToggleCheatsheet() {
        coordinator?.toggleCheatsheet()
    }

    @objc private func handleShowAbout() {
        let alert = NSAlert()
        alert.messageText = "FreeWindow"
        alert.informativeText = "Window Manager + Clipboard + Screenshot Pin\nVersion 1.0.0\n\nA native macOS productivity tool."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
