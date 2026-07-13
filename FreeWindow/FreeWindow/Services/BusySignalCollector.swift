// BusySignalCollector.swift — Live system snapshot used by BusyDetect.
// Calls into NSWorkspace and CoreGraphics. Test harnesses can supply
// `override` instead.

import Foundation
import AppKit
import CoreGraphics
import FreeWindowCore

public final class BusySignalCollector {
    public static let shared = BusySignalCollector()

    /// Test seam: when set, this is returned verbatim instead of probing
    /// the live system.
    public var override: (() -> BusySignals)?

    public init() {}

    public func collect() -> BusySignals {
        if let override { return override() }

        let processes = NSWorkspace.shared.runningApplications.compactMap { $0.localizedName }

        var anyMirrored = false
        let maxDisplays: UInt32 = 16
        var displayList = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var actualCount: UInt32 = 0
        let result = CGGetActiveDisplayList(maxDisplays, &displayList, &actualCount)
        if result == .success {
            for i in 0..<Int(actualCount) {
                let d = displayList[i]
                if CGDisplayIsInMirrorSet(d) != 0 {
                    anyMirrored = true
                    break
                }
            }
        }

        return BusySignals(
            processes: processes,
            displayMirrored: anyMirrored,
            captureActive: false,        // out of scope; needs ScreenCaptureKit
            audioInputInUse: false       // out of scope; needs CoreAudio probe
        )
    }
}
