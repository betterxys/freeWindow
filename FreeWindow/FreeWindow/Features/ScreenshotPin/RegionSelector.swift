// RegionSelector.swift — Full-screen overlay for interactive region capture.
// User clicks and drags to select a screen region; result is a captured image.
// Uses macOS `screencapture` command (works on macOS 15+ where CGWindowListCreateImage is obsoleted).

import AppKit

final class RegionSelector {
    private var overlayWindows: [NSWindow] = []
    private let completion: (NSImage, NSRect) -> Void

    init(completion: @escaping (NSImage, NSRect) -> Void) {
        self.completion = completion
    }

    func start() {
        // DO NOT call NSApp.activate here!
        // Our overlay is at .screenSaver level and appears above everything regardless.
        // Activating would steal focus from the user's current app, causing the desktop
        // to show through when we later hide the overlay for capture.

        // Create a transparent overlay window on each screen
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.15)
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false

            let view = SelectionOverlayView { [weak self] rect in
                self?.completeCapture(rect: rect)
            } onCancel: { [weak self] in
                self?.cancel()
            }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            overlayWindows.append(window)
        }

        NSCursor.crosshair.push()
        debugLog("[Screenshot] RegionSelector started. \(overlayWindows.count) overlays\n")
    }

    private func completeCapture(rect: NSRect) {
        // Hide overlays first so they don't appear in the capture
        cleanup()

        // Convert NSRect (bottom-left origin) to screencapture format (top-left origin)
        guard let primaryScreen = NSScreen.screens.first else { return }
        let primaryHeight = primaryScreen.frame.height

        let x = Int(rect.origin.x)
        let y = Int(primaryHeight - rect.origin.y - rect.height)
        let w = Int(rect.width)
        let h = Int(rect.height)

        debugLog("[Screenshot] Selection: NSRect=\(rect) -> screencapture x=\(x),y=\(y),w=\(w),h=\(h)\n")

        // Use screencapture command (works on macOS 15+, has system permissions)
        let tmpFile = "/tmp/freewindow_capture_\(UUID().uuidString).png"

        // Delay slightly to let overlays disappear from screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-x", "-R", "\(x),\(y),\(w),\(h)", tmpFile]

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0,
                   let image = NSImage(contentsOfFile: tmpFile) {
                    self.debugLog("[Screenshot] screencapture success: \(image.size)\n")
                    // Pin at the original screen location
                    self.completion(image, rect)
                } else {
                    self.debugLog("[Screenshot] screencapture failed: status=\(process.terminationStatus)\n")
                }

                // Cleanup temp file
                try? FileManager.default.removeItem(atPath: tmpFile)
            } catch {
                self.debugLog("[Screenshot] screencapture error: \(error)\n")
            }
        }
    }

    private func cancel() {
        cleanup()
    }

    private func cleanup() {
        NSCursor.pop()
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    private func debugLog(_ msg: String) {
        let logFile = "/tmp/freewindow_debug.log"
        if let data = msg.data(using: .utf8) {
            if let fh = FileHandle(forWritingAtPath: logFile) {
                fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
            } else {
                FileManager.default.createFile(atPath: logFile, contents: data)
            }
        }
    }
}

/// Overlay view that handles mouse drag for region selection.
final class SelectionOverlayView: NSView {
    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    private let onComplete: (NSRect) -> Void
    private let onCancel: () -> Void

    init(onComplete: @escaping (NSRect) -> Void, onCancel: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)

        currentRect = NSRect(x: x, y: y, width: w, height: h)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let rect = currentRect, rect.width > 5 && rect.height > 5 else {
            onCancel()
            return
        }

        // Convert view-local rect to screen coordinates
        guard let window = self.window else { return }
        let screenRect = window.convertToScreen(rect)
        onComplete(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let rect = currentRect {
            NSColor.systemBlue.withAlphaComponent(0.2).setFill()
            NSBezierPath(rect: rect).fill()

            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.stroke()
        }
    }
}
