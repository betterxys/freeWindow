// ScreenshotPinManager.swift — Manage capture and pinning of screenshots.

import AppKit

final class ScreenshotPinManager {
    private var pins: [UUID: PinnedImageWindow] = [:]
    private var regionSelector: RegionSelector?

    /// Start interactive region capture, then pin the result.
    func captureAndPin() {
        debugLog("[Screenshot] captureAndPin called\n")

        // Don't check/request permission here — just attempt capture.
        // If Screen Recording is not granted, CGWindowListCreateImage will
        // return only the wallpaper. The user needs to grant it once in
        // System Settings → Privacy & Security → Screen Recording.

        let selector = RegionSelector { [weak self] image, rect in
            self?.pinImage(image, at: rect)
            self?.regionSelector = nil
        }
        selector.start()
        self.regionSelector = selector
    }

    /// Pin an image at a specific screen location.
    func pinImage(_ image: NSImage, at rect: NSRect) {
        debugLog("[Screenshot] pinImage called. rect=\(rect), image.size=\(image.size)\n")
        let id = UUID()
        let window = PinnedImageWindow(image: image, frame: rect, id: id) { [weak self] pinnedId in
            self?.removePin(id: pinnedId)
        }
        window.show()
        pins[id] = window
        debugLog("[Screenshot] Pin created and shown. Total pins: \(pins.count)\n")
    }

    /// Remove a specific pin.
    func removePin(id: UUID) {
        pins[id]?.close()
        pins.removeValue(forKey: id)
    }

    /// Remove all pins.
    func removeAllPins() {
        for (_, window) in pins {
            window.close()
        }
        pins.removeAll()
        ToastService.shared.show("All pins removed")
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
