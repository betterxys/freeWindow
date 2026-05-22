import FreeWindowCore
// CheatsheetWindow.swift — Floating hotkey reference panel.
// Port of modules/cheatsheet.lua to native SwiftUI.

import AppKit
import SwiftUI

final class CheatsheetWindow {
    private var window: NSWindow?
    private var escMonitor: Any?

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func showCentered() {
        guard let screen = NSScreen.main else { return }

        let width: CGFloat = 820
        let height: CGFloat = 520

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - height / 2

        let win = NSWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "FreeWindow – Hotkey Cheatsheet"
        win.level = .floating
        win.isReleasedWhenClosed = false

        // Create the SwiftUI view and embed it directly in the content view
        // with explicit frame constraints to prevent SwiftUI from collapsing
        let hostingView = NSHostingView(rootView: CheatsheetView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        contentView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])

        win.contentView = contentView
        win.setContentSize(NSSize(width: width, height: height))
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win

        // Esc to dismiss
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.close()
                return nil
            }
            return event
        }
    }

    func close() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
        window?.orderOut(nil)
        window = nil
    }
}
