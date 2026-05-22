// ClipboardManager.swift — Clipboard history manager.
// Monitors NSPasteboard for changes, maintains a ring buffer of recent items.

import AppKit
import SwiftUI
import Combine

final class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    let maxItems: Int = 50

    private var pollTimer: Timer?
    private var lastChangeCount: Int = 0
    private var popupWindow: NSWindow?

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        appendDebugLog("[Clipboard] start() called. Initial changeCount=\(lastChangeCount)\n")
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        // Ensure the timer is added to the current run loop in common modes
        if let timer = pollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkForChanges() {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        if currentCount != lastChangeCount {
            appendDebugLog("[Clipboard] Change detected! \(lastChangeCount) -> \(currentCount)\n")
            lastChangeCount = currentCount

            // Determine content type and capture
            if let content = captureContent(from: pb) {
                // Deduplicate: don't add if same as most recent
                if case .text(let newText) = content,
                   case .text(let lastText) = history.first?.content,
                   newText == lastText {
                    return
                }

                let item = ClipboardItem(
                    id: UUID(),
                    content: content,
                    timestamp: Date(),
                    sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName
                )

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.history.insert(item, at: 0)
                    if self.history.count > self.maxItems {
                        self.history.removeLast()
                    }
                    self.appendDebugLog("[Clipboard] Added item. Total: \(self.history.count)\n")
                }
            } else {
                appendDebugLog("[Clipboard] Change detected but captureContent returned nil\n")
            }
        }
    }

    private func captureContent(from pb: NSPasteboard) -> ClipboardContent? {
        // Check for file URLs first
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            return .fileURLs(urls)
        }

        // Check for images
        if let image = NSImage(pasteboard: pb) {
            // Make sure it's not just a file URL that looks like an image
            if pb.types?.contains(.png) == true || pb.types?.contains(.tiff) == true {
                return .image(image)
            }
        }

        // Check for rich text
        if let rtfData = pb.data(forType: .rtf),
           let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            return .attributedText(attrStr)
        }

        // Fall back to plain text
        if let text = pb.string(forType: .string), !text.isEmpty {
            return .text(text)
        }

        return nil
    }

    // MARK: - Popup

    func togglePopup() {
        let msg = "[Clipboard] togglePopup called. history.count=\(history.count), popupVisible=\(popupWindow?.isVisible ?? false)\n"
        appendDebugLog(msg)

        if let window = popupWindow, window.isVisible {
            hidePopup()
        } else {
            showPopup()
        }
    }

    func showPopup() {
        hidePopup()

        let msg = "[Clipboard] showPopup. history=\(history.count) items\n"
        appendDebugLog(msg)

        guard let screen = NSScreen.main else {
            appendDebugLog("[Clipboard] ERROR: no main screen\n")
            return
        }
        let width: CGFloat = 400
        let height: CGFloat = 500

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - height / 2

        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clipboard History (\(history.count) items)"
        window.isReleasedWhenClosed = false

        // Use NSHostingView with constraints to avoid SwiftUI size collapse
        let hostingView = NSHostingView(rootView: ClipboardPopupView(manager: self))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        contentView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        window.contentView = contentView

        window.level = .floating
        window.setContentSize(NSSize(width: width, height: height))
        window.center()

        // Activate app BEFORE showing the window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        self.popupWindow = window
        appendDebugLog("[Clipboard] Window shown at center\n")
    }

    func hidePopup() {
        popupWindow?.orderOut(nil)
        popupWindow = nil
    }

    func paste(item: ClipboardItem) {
        hidePopup()

        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.content {
        case .text(let str):
            pb.setString(str, forType: .string)
        case .attributedText(let attrStr):
            if let rtfData = attrStr.rtf(from: NSRange(location: 0, length: attrStr.length)) {
                pb.setData(rtfData, forType: .rtf)
            }
            pb.setString(attrStr.string, forType: .string)
        case .image(let image):
            if let tiffData = image.tiffRepresentation {
                pb.setData(tiffData, forType: .tiff)
            }
        case .fileURLs(let urls):
            pb.writeObjects(urls as [NSURL])
        }

        // Update change count so we don't re-capture what we just pasted
        lastChangeCount = pb.changeCount

        // Simulate ⌘V after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func appendDebugLog(_ msg: String) {
        let logFile = "/tmp/freewindow_debug.log"
        if let data = msg.data(using: .utf8) {
            if let fh = FileHandle(forWritingAtPath: logFile) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            } else {
                FileManager.default.createFile(atPath: logFile, contents: data)
            }
        }
    }
}
