// BusyDetect.swift — Pure "is the user busy right now?" detector.
// Direct port of modules/busy_detect.lua. No AppKit, no NSRunningApplication;
// the caller passes in already-collected signals, so this is trivially
// testable.

import Foundation

public struct BusySignals: Equatable {
    public var processes: [String]            // running app names
    public var displayMirrored: Bool          // any screen has mirroring on
    public var captureActive: Bool            // screen recording / sharing
    public var audioInputInUse: Bool          // mic captured by something

    public init(
        processes: [String] = [],
        displayMirrored: Bool = false,
        captureActive: Bool = false,
        audioInputInUse: Bool = false
    ) {
        self.processes = processes
        self.displayMirrored = displayMirrored
        self.captureActive = captureActive
        self.audioInputInUse = audioInputInUse
    }
}

public struct BusyVerdict: Equatable {
    public var busy: Bool
    public var reasons: [String]
    public init(busy: Bool, reasons: [String]) {
        self.busy = busy; self.reasons = reasons
    }
}

public enum BusyDetect {

    // Apps that strongly imply "in a meeting" or "actively presenting /
    // streaming". Keys are case-insensitive substrings matched against
    // running-app names.
    //
    // We deliberately use *specific* substrings (e.g. "zoom.us" not "zoom")
    // so the auto-lock isn't suppressed by random tooling that shares a
    // name fragment with a meeting product (e.g. `lark-mcp`).
    public static let defaultBusyKeywords: [String] = [
        // Conferencing
        "zoom.us", "zoom meeting",
        "wemeet", "tencent meeting", "腾讯会议", "voov meeting",
        "feishu", "飞书",
        "lark.app", "lark meeting",
        "dingtalk", "钉钉",
        "microsoft teams", "msteams",
        "webex",
        "google meet",
        "skype.app",
        "classin",
        // Streaming / capture / presenting
        "obs.app", "obs studio",
        "streamlabs",
        "screenflow",
        "loom.app",
        "keynote",
        "powerpoint",
    ]

    public static func evaluate(
        signals: BusySignals,
        keywords: [String] = defaultBusyKeywords
    ) -> BusyVerdict {
        var reasons: [String] = []

        let hits = matchProcesses(signals.processes, keywords: keywords)
        if !hits.isEmpty {
            reasons.append("前台应用: " + hits.joined(separator: ", "))
        }
        if signals.displayMirrored { reasons.append("屏幕镜像") }
        if signals.captureActive   { reasons.append("屏幕录制/共享") }
        if signals.audioInputInUse { reasons.append("麦克风被占用") }

        return BusyVerdict(busy: !reasons.isEmpty, reasons: reasons)
    }

    // Substring match, case-insensitive, deduplicated.
    private static func matchProcesses(_ processes: [String], keywords: [String]) -> [String] {
        let lowerKeywords = keywords.map { $0.lowercased() }.filter { !$0.isEmpty }
        var hits: [String] = []
        var seen = Set<String>()
        for raw in processes {
            let lower = raw.lowercased()
            if lower.isEmpty { continue }
            for kw in lowerKeywords {
                if lower.contains(kw) {
                    if !seen.contains(raw) {
                        seen.insert(raw)
                        hits.append(raw)
                    }
                    break
                }
            }
        }
        return hits
    }
}
