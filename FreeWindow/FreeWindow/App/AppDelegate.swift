import FreeWindowCore
// AppDelegate.swift — Application lifecycle management.
// Handles: accessibility permission check, service initialization, hotkey registration.

import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: WindowManagerCoordinator?
    private var clipboardManager: ClipboardManager?
    private var screenshotPinManager: ScreenshotPinManager?
    private(set) var pomodoroController: PomodoroController?
    private let statusItemController = FreeWindowStatusItemController.shared

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
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePomodoroToggle),
            name: .pomodoroToggle, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePomodoroStatus),
            name: .pomodoroStatus, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePomodoroCancel),
            name: .pomodoroCancel, object: nil)

        // Start ALL hotkey services unconditionally (Carbon doesn't need AX permission)
        startAllServices()
        BundledAppInstaller.ensureIce()
        PermissionSetupService.shared.start()

        // If AX permission available, window management is ready immediately.
        // If not, poll until it becomes available (user toggles switch).
        if !axTrusted {
            startPermissionPolling()
        } else {
            BinarySignatureTracker.markTrusted()
        }

        ToastService.shared.show("FreeWindow 已启动：菜单栏图标可打开菜单")
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

        // Pomodoro: load user config, build the controller against the
        // production driver. Hotkeys registered alongside the others.
        let config = FreeWindowConfig.load()
        let driver = SystemPomodoroDriver()
        pomodoroController = PomodoroController(settings: config.pomodoro, driver: driver)
        pomodoroController?.onUpdate = { [weak self] in
            guard let controller = self?.pomodoroController else { return }
            DispatchQueue.main.async {
                PomodoroMenuBarState.shared.refresh(from: controller)
            }
        }
        if let controller = pomodoroController {
            PomodoroMenuBarState.shared.refresh(from: controller)
        }
        statusItemController.start()

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

        // Pomodoro hotkeys.
        //   ⌃⇧ + S    → pomodoro toggle (start/pause/resume)
        //   ⌃⌥⌘⇧ + .  → skip phase
        //   ⌃⌥⌘⇧ + X  → cancel
        //   ⌃⌥⌘⇧ + /  → status (shows toast with remaining time)
        hotkeyService.register(modifiers: [.ctrl, .shift], key: "s") { [weak self] in
            self?.pomodoroController?.toggle()
            ToastService.shared.show(self?.pomodoroController?.summary() ?? "")
        }
        hotkeyService.register(modifiers: HotkeyBindings.defaultHyperShift, key: ".") { [weak self] in
            self?.pomodoroController?.skip()
            ToastService.shared.show(self?.pomodoroController?.summary() ?? "")
        }
        hotkeyService.register(modifiers: HotkeyBindings.defaultHyperShift, key: "x") { [weak self] in
            BreakReminderService.shared.dismiss()
            self?.pomodoroController?.cancel()
            ToastService.shared.show(self?.pomodoroController?.summary() ?? "")
        }
        hotkeyService.register(modifiers: HotkeyBindings.defaultHyperShift, key: "/") { [weak self] in
            ToastService.shared.show(self?.pomodoroController?.summary() ?? "")
        }
    }

    /// Poll until accessibility becomes available (for window movement to work).
    private func startPermissionPolling() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            if AXIsProcessTrusted() {
                self?.permissionTimer?.invalidate()
                self?.permissionTimer = nil
                BinarySignatureTracker.markTrusted()
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
        BreakReminderService.shared.dismiss()
        pomodoroController?.cancel()
    }

    /// Prevent the app from terminating when the last window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItemController.presentMenu()
        return false
    }

    // MARK: - Notifications (always work, no accessibility needed)

    @objc private func handleToggleCheatsheet() {
        coordinator?.toggleCheatsheet()
    }

    @objc private func handleShowAbout() {
        let alert = NSAlert()
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "development"
        alert.messageText = "FreeWindow"
        alert.informativeText = """
        Window Manager + Clipboard + Screenshot Pin + Pomodoro
        Version \(version)

        A native macOS productivity tool.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc fileprivate func handlePomodoroToggle() {
        pomodoroController?.toggle()
        ToastService.shared.show(pomodoroController?.summary() ?? "")
    }

    @objc fileprivate func handlePomodoroStatus() {
        ToastService.shared.show(pomodoroController?.summary() ?? "")
    }

    @objc fileprivate func handlePomodoroCancel() {
        BreakReminderService.shared.dismiss()
        pomodoroController?.cancel()
        ToastService.shared.show(pomodoroController?.summary() ?? "")
    }
}
