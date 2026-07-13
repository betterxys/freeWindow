// FreeWindowStatusItemController.swift — Single right-side menu bar item.
// Shows the app icon when idle, pomodoro timer when running, and the app menu on click.

import AppKit
import Combine

final class FreeWindowStatusItemController: NSObject {
    static let shared = FreeWindowStatusItemController()

    private var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?

    private lazy var appIcon: NSImage = {
        let image = NSImage(
            systemSymbolName: "rectangle.split.2x2",
            accessibilityDescription: "FreeWindow"
        )!
        image.isTemplate = true
        return image
    }()

    func start() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Use a fresh autosave name so macOS/Ice do not reuse a previously
        // hidden or removed state for the old image-only item.
        item.autosaveName = "FreeWindowStatusItem"

        if let button = item.button {
            button.target = self
            button.action = #selector(showMenu(_:))
            button.toolTip = "FreeWindow"
            button.setAccessibilityTitle("FreeWindow")
        }

        statusItem = item

        cancellable = PomodoroMenuBarState.shared.$label
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAppearance()
            }

        refreshAppearance()
    }

    func presentMenu() {
        guard let button = statusItem?.button else { return }
        showMenu(button)
    }

    private func refreshAppearance() {
        guard let button = statusItem?.button else { return }
        if let label = PomodoroMenuBarState.shared.label {
            button.image = nil
            button.title = label
            button.setAccessibilityTitle(label)
            button.font = NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.smallSystemFontSize,
                weight: .medium
            )
        } else {
            button.image = nil
            button.title = "FW"
            button.font = NSFont.monospacedSystemFont(
                ofSize: NSFont.smallSystemFontSize,
                weight: .semibold
            )
            button.setAccessibilityTitle("FreeWindow")
        }
    }

    @objc private func showMenu(_ sender: NSStatusBarButton) {
        let menu = buildMenu()
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: sender.bounds.height + 2),
            in: sender
        )
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        if PomodoroMenuBarState.shared.isActive {
            let header = NSMenuItem(
                title: PomodoroMenuBarState.shared.detailText,
                action: nil,
                keyEquivalent: ""
            )
            header.isEnabled = false
            menu.addItem(header)
            menu.addItem(.separator())
        }

        menu.addItem(item("Show Cheatsheet (⌃⌥⌘/)", action: #selector(toggleCheatsheet)))
        menu.addItem(.separator())

        let pomodoroHeader = NSMenuItem(title: "Pomodoro", action: nil, keyEquivalent: "")
        pomodoroHeader.isEnabled = false
        menu.addItem(pomodoroHeader)
        menu.addItem(item("Start / Pause / Resume (⌃⇧S)", action: #selector(pomodoroToggle)))
        menu.addItem(item("Show Status (⌃⌥⌘⇧/)", action: #selector(pomodoroStatus)))
        menu.addItem(item("Cancel (⌃⌥⌘⇧X)", action: #selector(pomodoroCancel)))
        menu.addItem(.separator())
        menu.addItem(item("辅助功能设置…", action: #selector(openAccessibilitySettings)))
        menu.addItem(item("About FreeWindow", action: #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item("Quit FreeWindow", action: #selector(quit), keyEquivalent: "q"))
        return menu
    }

    private func item(
        _ title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.target = self
        return menuItem
    }

    @objc private func toggleCheatsheet() {
        NotificationCenter.default.post(name: .toggleCheatsheet, object: nil)
    }

    @objc private func pomodoroToggle() {
        NotificationCenter.default.post(name: .pomodoroToggle, object: nil)
    }

    @objc private func pomodoroStatus() {
        NotificationCenter.default.post(name: .pomodoroStatus, object: nil)
    }

    @objc private func pomodoroCancel() {
        NotificationCenter.default.post(name: .pomodoroCancel, object: nil)
    }

    @objc private func showAbout() {
        NotificationCenter.default.post(name: .showAbout, object: nil)
    }

    @objc private func openAccessibilitySettings() {
        PermissionSetupService.shared.openSettingsFromMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
