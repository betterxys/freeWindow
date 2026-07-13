// FreeWindowApp.swift — Application entry point.
// Menu-bar-only app (LSUIElement), no Dock icon, no console window.

import SwiftUI
import AppKit

@main
struct FreeWindowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar UI is handled by FreeWindowStatusItemController (AppKit NSStatusItem).
        Settings { EmptyView() }
    }
}

extension Notification.Name {
    static let toggleCheatsheet = Notification.Name("FreeWindow.toggleCheatsheet")
    static let showAbout = Notification.Name("FreeWindow.showAbout")
    static let pomodoroToggle = Notification.Name("FreeWindow.pomodoroToggle")
    static let pomodoroStatus = Notification.Name("FreeWindow.pomodoroStatus")
    static let pomodoroCancel = Notification.Name("FreeWindow.pomodoroCancel")
}
