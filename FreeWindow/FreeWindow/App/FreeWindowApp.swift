// FreeWindowApp.swift — Application entry point.
// Menu-bar-only app (LSUIElement), no Dock icon, no console window.

import SwiftUI
import AppKit

@main
struct FreeWindowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("FreeWindow", systemImage: "rectangle.split.2x2") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Menu bar dropdown content.
struct MenuBarView: View {
    var body: some View {
        Button("Show Cheatsheet (⌃⌥⌘/)") {
            NotificationCenter.default.post(name: .toggleCheatsheet, object: nil)
        }
        Divider()
        Button("About FreeWindow") {
            NotificationCenter.default.post(name: .showAbout, object: nil)
        }
        Divider()
        Button("Quit FreeWindow") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

extension Notification.Name {
    static let toggleCheatsheet = Notification.Name("FreeWindow.toggleCheatsheet")
    static let showAbout = Notification.Name("FreeWindow.showAbout")
}
