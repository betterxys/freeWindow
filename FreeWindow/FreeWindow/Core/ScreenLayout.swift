// ScreenLayout.swift — Display ordering and resolver.
// Direct port of modules/screens.lua.
// Sorts screens by physical position (left→right, top→bottom).

import Foundation

/// Information about a single screen/display.
public struct ScreenInfo: Equatable, Codable {
    public let id: UInt32
    public let name: String?
    public let frame: WMRect

    public init(id: UInt32, name: String?, frame: WMRect) {
        self.id = id; self.name = name; self.frame = frame
    }
}

/// Grid configuration for nudge/resize operations.
public struct Grid: Equatable, Codable {
    public let cols: Int
    public let rows: Int

    public init(cols: Int, rows: Int) {
        self.cols = cols; self.rows = rows
    }

    public static let `default` = Grid(cols: 12, rows: 8)
}

/// Sorts and provides stable lookup for screens.
public final class ScreenResolver {
    public let ordered: [ScreenInfo]
    public let count: Int

    private let byId: [UInt32: Int]
    private let byName: [String: Int]
    private let roles: [String: Int]

    public init(screens: [ScreenInfo], roleMap: [String: Any] = [:]) {
        // Sort left→right, then top→bottom, then by id for stability.
        self.ordered = Self.order(screens)
        self.count = ordered.count

        var byId: [UInt32: Int] = [:]
        var byName: [String: Int] = [:]
        for (i, s) in ordered.enumerated() {
            byId[s.id] = i
            if let name = s.name {
                byName[name] = i
            }
        }
        self.byId = byId
        self.byName = byName

        // Resolve role map: values can be Int (1-based index) or String (screen name).
        var roles: [String: Int] = [:]
        for (role, target) in roleMap {
            if let idx = target as? Int {
                roles[role] = idx - 1  // Convert 1-based to 0-based
            } else if let name = target as? String {
                roles[role] = byName[name]
            }
        }
        self.roles = roles
    }

    /// Sort screens by physical position: left→right, then top→bottom.
    public static func order(_ screens: [ScreenInfo]) -> [ScreenInfo] {
        screens.sorted { a, b in
            if a.frame.x != b.frame.x { return a.frame.x < b.frame.x }
            if a.frame.y != b.frame.y { return a.frame.y < b.frame.y }
            return a.id < b.id
        }
    }

    public func frame(at index: Int) -> WMRect? {
        guard index >= 0 && index < count else { return nil }
        return ordered[index].frame
    }

    public func indexForId(_ id: UInt32) -> Int? {
        byId[id]
    }

    public func indexForName(_ name: String) -> Int? {
        byName[name]
    }

    public func indexForRole(_ role: String) -> Int? {
        roles[role]
    }

    /// Cycle to next screen index (wraps around). 0-based.
    public func nextIndex(from current: Int, step: Int = 1) -> Int? {
        guard count > 0 else { return nil }
        var n = (current + step) % count
        if n < 0 { n += count }
        return n
    }
}
