import FreeWindowCore
// ScreenService.swift — Monitor enumeration and reconfiguration detection.
// Wraps NSScreen and CGDisplay APIs.

import AppKit
import CoreGraphics

/// Service for screen/display management.
final class ScreenService {
    static let shared = ScreenService()

    private var displayCallback: CGDisplayReconfigurationCallBack?
    var onChange: (() -> Void)?

    /// Get all screens ordered by physical position (left→right, top→bottom).
    func orderedScreens() -> [ScreenInfo] {
        let nsScreens = NSScreen.screens
        let infos = nsScreens.map { screen -> ScreenInfo in
            let displayId = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
            // Use visibleFrame (excludes menu bar / Dock)
            let vf = screen.visibleFrame
            // Convert from NSScreen coordinate system (bottom-left origin)
            // to top-left origin (which is what AXUIElement uses)
            let frame = convertToTopLeft(nsRect: vf)
            return ScreenInfo(id: displayId, name: screen.localizedName, frame: frame)
        }
        return ScreenResolver.order(infos)
    }

    /// Start watching for display configuration changes.
    func startWatching(onChange: @escaping () -> Void) {
        self.onChange = onChange
        CGDisplayRegisterReconfigurationCallback(displayReconfigCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    /// Stop watching.
    func stopWatching() {
        CGDisplayRemoveReconfigurationCallback(displayReconfigCallback, Unmanaged.passUnretained(self).toOpaque())
        self.onChange = nil
    }

    // MARK: - Coordinate conversion

    /// Convert NSScreen visibleFrame (bottom-left origin) to top-left origin frame.
    private func convertToTopLeft(nsRect: NSRect) -> WMRect {
        // The primary screen's frame gives us the total coordinate space.
        guard let primaryScreen = NSScreen.screens.first else {
            return WMRect(x: Int(nsRect.origin.x), y: Int(nsRect.origin.y),
                          w: Int(nsRect.size.width), h: Int(nsRect.size.height))
        }
        let primaryHeight = primaryScreen.frame.size.height
        let topLeftY = primaryHeight - nsRect.origin.y - nsRect.size.height
        return WMRect(
            x: Int(nsRect.origin.x),
            y: Int(topLeftY),
            w: Int(nsRect.size.width),
            h: Int(nsRect.size.height)
        )
    }
}

/// C callback for display reconfiguration.
private func displayReconfigCallback(
    display: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags,
    userInfo: UnsafeMutableRawPointer?
) {
    // Only react to completed reconfiguration (not the "begin" phase)
    guard flags.contains(.beginConfigurationFlag) == false,
          let userInfo = userInfo else { return }

    let service = Unmanaged<ScreenService>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async {
        service.onChange?()
    }
}

// Make onChange accessible to the C callback (already internal visibility)
