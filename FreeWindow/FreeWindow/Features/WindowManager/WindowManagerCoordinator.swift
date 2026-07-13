import FreeWindowCore
// WindowManagerCoordinator.swift — The brain of window management.
// Equivalent of modules/driver.lua: connects hotkeys → actions → window moves.

import AppKit

final class WindowManagerCoordinator {
    private let accessibility = AccessibilityService.shared
    private let screenService = ScreenService.shared
    private let hotkeyService = HotkeyService.shared
    private let toast = ToastService.shared

    private var cheatsheetWindow: CheatsheetWindow?
    private var layoutStore: LayoutStore?

    func start() {
        // Install the Carbon event handler FIRST, then register hotkeys
        hotkeyService.start()
        installBindings()
        screenService.startWatching { [weak self] in
            self?.handleScreenLayoutChange()
        }

        let layoutDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".freewindow/layouts")
        try? FileManager.default.createDirectory(at: layoutDir, withIntermediateDirectories: true)
        layoutStore = LayoutStore(directory: layoutDir)

        // Write diagnostic log
        let log = "[FreeWindow] Started. Hotkeys registered: \(hotkeyService.registeredCount), running: \(hotkeyService.isRunning)\n"
        try? log.write(toFile: "/tmp/freewindow_startup.log", atomically: true, encoding: .utf8)

        toast.show("FreeWindow loaded (\(hotkeyService.registeredCount) hotkeys)")
    }

    func stop() {
        hotkeyService.stop()
        screenService.stopWatching()
    }

    // MARK: - Binding Installation

    private func installBindings() {
        hotkeyService.unregisterAll()
        let bindings = HotkeyBindings.build()

        // Check for conflicts
        let conflicts = HotkeyBindings.detectConflicts(bindings)
        if !conflicts.isEmpty {
            let msg = conflicts.map { c in
                "\(c.key) → \(c.names.joined(separator: ", "))"
            }.joined(separator: "\n")
            toast.show("Hotkey conflicts:\n\(msg)")
        }

        // Register window management hotkeys
        for binding in bindings {
            hotkeyService.register(modifiers: binding.modifiers, key: binding.key) { [weak self] in
                self?.executeAction(binding.action)
            }
        }

        // Layout save/restore
        hotkeyService.register(modifiers: HotkeyBindings.defaultHyper, key: "s") { [weak self] in
            self?.saveLayout()
        }
        hotkeyService.register(modifiers: HotkeyBindings.defaultHyper, key: "r") { [weak self] in
            self?.restoreLayout()
        }

        // Cheatsheet
        hotkeyService.register(modifiers: HotkeyBindings.defaultHyper, key: "/") { [weak self] in
            self?.toggleCheatsheet()
        }
    }

    private func handleScreenLayoutChange() {
        // Window actions resolve NSScreen dynamically at execution time, so
        // no hotkey re-registration is needed. Stopping the shared hotkey
        // service here used to erase clipboard, screenshot, and pomodoro
        // shortcuts registered by AppDelegate.
        toast.show("Screen layout changed")
    }

    // MARK: - Action Execution

    private func executeAction(_ action: @escaping (ActionContext) -> WMRect?) {
        appendWindowLog("[WindowManager] action requested frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil") AX=\(AXIsProcessTrusted())\n")
        guard AXIsProcessTrusted() else {
            PermissionSetupService.shared.notifyHotkeyBlocked()
            appendWindowLog("[WindowManager] blocked: AX not trusted\n")
            return
        }
        guard let ctx = buildContext() else {
            appendWindowLog("[WindowManager] blocked: no focused window context\n")
            return
        }
        guard let targetFrame = action(ctx.context) else {
            appendWindowLog("[WindowManager] no-op: action returned nil currentScreen=\(ctx.context.screenIndex)\n")
            return
        }
        appendWindowLog("[WindowManager] setFrame from=\(ctx.context.windowFrame) screen=\(ctx.context.screenIndex) to=\(targetFrame)\n")
        ctx.window.setFrame(targetFrame)
    }

    private func buildContext() -> (context: ActionContext, window: AXWindow)? {
        guard let win = accessibility.focusedWindow(),
              let winFrame = win.frame else { return nil }

        let screens = screenService.orderedScreens()
        guard !screens.isEmpty else { return nil }
        let resolver = ScreenResolver(screens: screens)

        let screenIdx = Geometry.screenForRect(screens: screens, rect: winFrame) ?? 0

        let ctx = ActionContext(
            windowFrame: winFrame,
            screenIndex: screenIdx,
            screens: resolver.ordered,
            resolver: resolver,
            grid: .default
        )
        return (ctx, win)
    }

    private func appendWindowLog(_ msg: String) {
        let logFile = "/tmp/freewindow_window.log"
        guard let data = msg.data(using: .utf8) else { return }
        if let fh = FileHandle(forWritingAtPath: logFile) {
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        } else {
            FileManager.default.createFile(atPath: logFile, contents: data)
        }
    }

    // MARK: - Layout Save/Restore

    private func saveLayout() {
        guard AXIsProcessTrusted() else {
            PermissionSetupService.shared.notifyHotkeyBlocked()
            return
        }
        guard let store = layoutStore else { return }
        let windows = accessibility.visibleWindows()
        let screens = screenService.orderedScreens()
        let resolver = ScreenResolver(screens: screens)

        let layoutWindows: [LayoutWindowInfo] = windows.compactMap { win in
            guard let frame = win.frame else { return nil }
            let screenIdx = Geometry.screenForRect(screens: screens, rect: frame) ?? 0
            return LayoutWindowInfo(
                id: Int(win.windowId ?? 0),
                title: win.title,
                app: win.appName,
                screenIndex: screenIdx,
                frame: frame
            )
        }

        let world = LayoutWorld(screens: resolver.ordered, windows: layoutWindows)
        let snapshot = LayoutSnapshot_.capture(world: world)
        store.save(snapshot, name: "default")
        toast.show("Layout saved")
    }

    private func restoreLayout() {
        guard let store = layoutStore,
              let snapshot = store.load(name: "default") else {
            toast.show("No saved layout found")
            return
        }

        let windows = accessibility.visibleWindows()
        let screens = screenService.orderedScreens()
        let resolver = ScreenResolver(screens: screens)

        let currentWindows: [LayoutWindowInfo] = windows.compactMap { win in
            guard let frame = win.frame else { return nil }
            let screenIdx = Geometry.screenForRect(screens: screens, rect: frame) ?? 0
            return LayoutWindowInfo(
                id: Int(win.windowId ?? 0),
                title: win.title,
                app: win.appName,
                screenIndex: screenIdx,
                frame: frame
            )
        }

        let currentWorld = LayoutWorld(screens: resolver.ordered, windows: currentWindows)
        let plan = LayoutSnapshot_.planRestore(snapshot: snapshot, currentWorld: currentWorld)

        // Build id→window map
        var byId: [Int: AXWindow] = [:]
        for win in windows {
            if let wid = win.windowId {
                byId[Int(wid)] = win
            }
        }

        for cmd in plan.commands {
            byId[cmd.windowId]?.setFrame(cmd.frame)
        }

        toast.show("Restored \(plan.commands.count) windows (\(plan.unresolved.count) unresolved)")
    }

    // MARK: - Extra Hotkeys

    func registerExtraHotkey(modifiers: Set<HotkeyModifier>, key: String, name: String, handler: @escaping () -> Void) {
        hotkeyService.register(modifiers: modifiers, key: key, handler: handler)
    }

    // MARK: - Cheatsheet

    func toggleCheatsheet() {
        if let w = cheatsheetWindow, w.isVisible {
            cheatsheetWindow?.close()
            cheatsheetWindow = nil
        } else {
            cheatsheetWindow = CheatsheetWindow()
            cheatsheetWindow?.showCentered()
        }
    }
}

// MARK: - Layout Store

final class LayoutStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func save(_ snapshot: LayoutSnapshot, name: String) {
        let url = directory.appendingPathComponent("\(name).json")
        let data = LayoutSnapshot_.serialize(snapshot)
        try? data.write(to: url)
    }

    func load(name: String) -> LayoutSnapshot? {
        let url = directory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return LayoutSnapshot_.deserialize(data)
    }
}
