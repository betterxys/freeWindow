// Rect.swift — Value type for window/screen rectangles.
// Matches the Lua `{ x, y, w, h }` convention with integer coordinates
// (rounded to pixel grid, preventing floating-point drift in tests).

import Foundation
import CoreGraphics

/// A rectangle in global screen coordinates (top-left origin, like macOS).
public struct WMRect: Equatable, Codable, Hashable {
    public let x: Int
    public let y: Int
    public let w: Int
    public let h: Int

    /// Round with the same EPS logic as geometry.lua.
    private static let eps: Double = 1e-6

    private static func wmRound(_ n: Double) -> Int {
        if n >= 0 {
            return Int(Foundation.floor(n + 0.5 + eps))
        } else {
            return -Int(Foundation.floor(-n + 0.5 + eps))
        }
    }

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = Self.wmRound(x)
        self.y = Self.wmRound(y)
        self.w = Self.wmRound(w)
        self.h = Self.wmRound(h)
    }

    public init(x: Int, y: Int, w: Int, h: Int) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public init(from cgRect: CGRect) {
        self.init(
            x: Double(cgRect.origin.x),
            y: Double(cgRect.origin.y),
            w: Double(cgRect.size.width),
            h: Double(cgRect.size.height)
        )
    }

    public var cgRect: CGRect {
        CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h))
    }
}

/// Fractional rectangle (each component typically in [0, 1] range).
public struct FractionalRect: Equatable {
    public let x: Double
    public let y: Double
    public let w: Double
    public let h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }
}
