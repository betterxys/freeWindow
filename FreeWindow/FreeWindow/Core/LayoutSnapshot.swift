// LayoutSnapshot.swift — Capture and restore window layouts.
// Port of modules/layouts.lua. Uses JSON serialization (not Lua tables).

import Foundation

/// A snapshot of one window's position in a layout.
public struct WindowSnapshot: Codable, Equatable {
    public let windowId: Int
    public let title: String?
    public let app: String?
    public let screenIndex: Int
    public let ratios: FractionalRectCodable  // Position as fractions of its screen
}

/// Codable-friendly fractional rect.
public struct FractionalRectCodable: Codable, Equatable {
    let x: Double
    let y: Double
    let w: Double
    let h: Double

    public init(_ fr: FractionalRect) {
        self.x = fr.x; self.y = fr.y; self.w = fr.w; self.h = fr.h
    }

    public var fractionalRect: FractionalRect {
        FractionalRect(x: x, y: y, w: w, h: h)
    }
}

/// A full layout snapshot (multiple windows + screen info for ratio context).
public struct LayoutSnapshot: Codable, Equatable {
    public let screens: [ScreenInfo]
    public let windows: [WindowSnapshot]
}

/// A restore command: "set this window to this frame".
public struct RestoreCommand {
    public let windowId: Int
    public let frame: WMRect
}

/// Result of planning a layout restore.
public struct RestorePlan {
    public let commands: [RestoreCommand]
    public let unresolved: [WindowSnapshot]
}

/// World state for layout operations.
public struct LayoutWorld {
    public init(screens: [ScreenInfo], windows: [LayoutWindowInfo]) { self.screens = screens; self.windows = windows }
    public let screens: [ScreenInfo]
    public let windows: [LayoutWindowInfo]
}

public struct LayoutWindowInfo {
    public init(id: Int, title: String?, app: String?, screenIndex: Int, frame: WMRect) { self.id = id; self.title = title; self.app = app; self.screenIndex = screenIndex; self.frame = frame }
    public let id: Int
    public let title: String?
    public let app: String?
    public let screenIndex: Int
    public let frame: WMRect
}

public enum LayoutSnapshot_ {

    // MARK: - Capture

    /// Capture current world into a restorable snapshot.
    public static func capture(world: LayoutWorld) -> LayoutSnapshot {
        let windowSnapshots = world.windows.map { w -> WindowSnapshot in
            let screen = world.screens[w.screenIndex]
            let ratios = Geometry.ratiosOf(rect: w.frame, frame: screen.frame)
            return WindowSnapshot(
                windowId: w.id,
                title: w.title,
                app: w.app,
                screenIndex: w.screenIndex,
                ratios: FractionalRectCodable(ratios)
            )
        }
        return LayoutSnapshot(screens: world.screens, windows: windowSnapshots)
    }

    // MARK: - Restore planning

    /// Plan how to restore a snapshot onto the current world.
    /// Matching strategy (in priority order):
    ///   1. Same window ID still exists → match
    ///   2. Same app + same title → match
    ///   3. Same app (only one unmatched window of that app) → match
    ///   4. Otherwise → unresolved
    public static func planRestore(snapshot: LayoutSnapshot, currentWorld: LayoutWorld) -> RestorePlan {
        var commands: [RestoreCommand] = []
        var unresolved: [WindowSnapshot] = []

        // Build lookup of current windows
        var availableById: [Int: LayoutWindowInfo] = [:]
        var availableByAppTitle: [String: [LayoutWindowInfo]] = [:]
        var availableByApp: [String: [LayoutWindowInfo]] = [:]

        for w in currentWorld.windows {
            availableById[w.id] = w
            if let app = w.app {
                let key = "\(app)|\(w.title ?? "")"
                availableByAppTitle[key, default: []].append(w)
                availableByApp[app, default: []].append(w)
            }
        }

        var matched: Set<Int> = []  // Window IDs already matched

        for snap in snapshot.windows {
            var targetWindow: LayoutWindowInfo?

            // Strategy 1: by ID
            if let w = availableById[snap.windowId], !matched.contains(w.id) {
                targetWindow = w
            }
            // Strategy 2: by app+title
            else if let app = snap.app {
                let key = "\(app)|\(snap.title ?? "")"
                if let candidates = availableByAppTitle[key] {
                    targetWindow = candidates.first { !matched.contains($0.id) }
                }
            }
            // Strategy 3: by app alone (only if unambiguous)
            if targetWindow == nil, let app = snap.app {
                if let candidates = availableByApp[app] {
                    let unmatched = candidates.filter { !matched.contains($0.id) }
                    if unmatched.count == 1 {
                        targetWindow = unmatched.first
                    }
                }
            }

            if let win = targetWindow {
                matched.insert(win.id)
                // Compute target frame: apply saved ratios to current screen
                let screenIdx = min(snap.screenIndex, currentWorld.screens.count - 1)
                let screenFrame = currentWorld.screens[max(0, screenIdx)].frame
                let frame = Geometry.fractional(frame: screenFrame, frac: snap.ratios.fractionalRect)
                commands.append(RestoreCommand(windowId: win.id, frame: frame))
            } else {
                unresolved.append(snap)
            }
        }

        return RestorePlan(commands: commands, unresolved: unresolved)
    }

    // MARK: - Serialization

    public static func serialize(_ snapshot: LayoutSnapshot) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(snapshot)) ?? Data()
    }

    public static func deserialize(_ data: Data) -> LayoutSnapshot? {
        try? JSONDecoder().decode(LayoutSnapshot.self, from: data)
    }
}
