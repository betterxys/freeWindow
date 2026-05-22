// Geometry.swift — Pure geometry helpers for window placement.
// Direct 1:1 port of modules/geometry.lua.
// Zero dependencies on AppKit/Accessibility — fully testable.

import Foundation

public enum Half: String, CaseIterable {
    case left, right, top, bottom
}

public enum Quadrant: String, CaseIterable {
    case nw, ne, sw, se
}

public enum Third: String, CaseIterable {
    case left, center, right
}

public enum TwoThirdsSide: String, CaseIterable {
    case left, right
}

public enum Direction: String, CaseIterable {
    case left, right, up, down
}

public enum MoveMode: String {
    case ratios, size, center
}

public enum Geometry {

    // MARK: - Basic constructors

    /// Build a sub-rectangle of `frame` from fractional coordinates.
    public static func fractional(frame: WMRect, frac: FractionalRect) -> WMRect {
        WMRect(
            x: Double(frame.x) + Double(frame.w) * frac.x,
            y: Double(frame.y) + Double(frame.h) * frac.y,
            w: Double(frame.w) * frac.w,
            h: Double(frame.h) * frac.h
        )
    }

    /// Cell in a uniform cols×rows grid on `frame`. col, row are 1-indexed.
    public static func gridCell(frame: WMRect, cols: Int, rows: Int,
                         col: Int, row: Int,
                         spanCols: Int = 1, spanRows: Int = 1) -> WMRect {
        precondition(col >= 1 && col <= cols, "col out of range")
        precondition(row >= 1 && row <= rows, "row out of range")
        return WMRect(
            x: Double(frame.x) + Double(frame.w) * Double(col - 1) / Double(cols),
            y: Double(frame.y) + Double(frame.h) * Double(row - 1) / Double(rows),
            w: Double(frame.w) * Double(spanCols) / Double(cols),
            h: Double(frame.h) * Double(spanRows) / Double(rows)
        )
    }

    // MARK: - Halves

    public static func half(frame: WMRect, _ which: Half) -> WMRect {
        switch which {
        case .left:   return fractional(frame: frame, frac: FractionalRect(x: 0, y: 0, w: 0.5, h: 1))
        case .right:  return fractional(frame: frame, frac: FractionalRect(x: 0.5, y: 0, w: 0.5, h: 1))
        case .top:    return fractional(frame: frame, frac: FractionalRect(x: 0, y: 0, w: 1, h: 0.5))
        case .bottom: return fractional(frame: frame, frac: FractionalRect(x: 0, y: 0.5, w: 1, h: 0.5))
        }
    }

    // MARK: - Quadrants

    public static func quadrant(frame: WMRect, _ which: Quadrant) -> WMRect {
        let frac: FractionalRect
        switch which {
        case .nw: frac = FractionalRect(x: 0,   y: 0,   w: 0.5, h: 0.5)
        case .ne: frac = FractionalRect(x: 0.5, y: 0,   w: 0.5, h: 0.5)
        case .sw: frac = FractionalRect(x: 0,   y: 0.5, w: 0.5, h: 0.5)
        case .se: frac = FractionalRect(x: 0.5, y: 0.5, w: 0.5, h: 0.5)
        }
        return fractional(frame: frame, frac: frac)
    }

    // MARK: - Thirds

    public static func third(frame: WMRect, _ which: Third) -> WMRect {
        let frac: FractionalRect
        switch which {
        case .left:   frac = FractionalRect(x: 0,       y: 0, w: 1.0/3.0, h: 1)
        case .center: frac = FractionalRect(x: 1.0/3.0, y: 0, w: 1.0/3.0, h: 1)
        case .right:  frac = FractionalRect(x: 2.0/3.0, y: 0, w: 1.0/3.0, h: 1)
        }
        return fractional(frame: frame, frac: frac)
    }

    public static func twoThirds(frame: WMRect, _ which: TwoThirdsSide) -> WMRect {
        switch which {
        case .left:  return fractional(frame: frame, frac: FractionalRect(x: 0, y: 0, w: 2.0/3.0, h: 1))
        case .right: return fractional(frame: frame, frac: FractionalRect(x: 1.0/3.0, y: 0, w: 2.0/3.0, h: 1))
        }
    }

    // MARK: - Maximize & Center

    public static func maximize(frame: WMRect) -> WMRect {
        frame
    }

    public static func centered(frame: WMRect, rect: WMRect) -> WMRect {
        WMRect(
            x: Double(frame.x) + Double(frame.w - rect.w) / 2.0,
            y: Double(frame.y) + Double(frame.h - rect.h) / 2.0,
            w: Double(rect.w),
            h: Double(rect.h)
        )
    }

    // MARK: - Ratios

    /// Describe `rect` as fractions of `frame`. Inverse of `fractional`.
    public static func ratiosOf(rect: WMRect, frame: WMRect) -> FractionalRect {
        precondition(frame.w > 0 && frame.h > 0, "frame must be non-empty")
        return FractionalRect(
            x: Double(rect.x - frame.x) / Double(frame.w),
            y: Double(rect.y - frame.y) / Double(frame.h),
            w: Double(rect.w) / Double(frame.w),
            h: Double(rect.h) / Double(frame.h)
        )
    }

    // MARK: - Clamp

    /// Clamp `rect` so it fits entirely within `frame`.
    public static func clamp(rect: WMRect, frame: WMRect) -> WMRect {
        let w = min(rect.w, frame.w)
        let h = min(rect.h, frame.h)
        let x = max(frame.x, min(rect.x, frame.x + frame.w - w))
        let y = max(frame.y, min(rect.y, frame.y + frame.h - h))
        return WMRect(x: x, y: y, w: w, h: h)
    }

    // MARK: - Cross-screen move

    /// Move `rect` to a different screen while preserving relative position.
    public static func moveToScreen(rect: WMRect, from: WMRect, to: WMRect, mode: MoveMode = .ratios) -> WMRect {
        switch mode {
        case .ratios:
            return fractional(frame: to, frac: ratiosOf(rect: rect, frame: from))
        case .size:
            let r = ratiosOf(rect: rect, frame: from)
            let target = WMRect(
                x: Double(to.x) + Double(to.w) * r.x,
                y: Double(to.y) + Double(to.h) * r.y,
                w: Double(rect.w),
                h: Double(rect.h)
            )
            return clamp(rect: target, frame: to)
        case .center:
            return centered(frame: to, rect: rect)
        }
    }

    // MARK: - Nudge & Resize

    /// Nudge by one grid cell in a cardinal direction, clamped to frame.
    public static func nudge(rect: WMRect, frame: WMRect, direction: Direction, cols: Int = 12, rows: Int = 8) -> WMRect {
        let stepX = Double(frame.w) / Double(cols)
        let stepY = Double(frame.h) / Double(rows)
        var dx: Double = 0
        var dy: Double = 0
        switch direction {
        case .left:  dx = -stepX
        case .right: dx = stepX
        case .up:    dy = -stepY
        case .down:  dy = stepY
        }
        let target = WMRect(x: Double(rect.x) + dx, y: Double(rect.y) + dy, w: Double(rect.w), h: Double(rect.h))
        return clamp(rect: target, frame: frame)
    }

    /// Grow/shrink width by one grid column, anchored on left edge.
    public static func resizeWidth(rect: WMRect, frame: WMRect, deltaCols: Int, cols: Int = 12) -> WMRect {
        let step = Double(frame.w) / Double(cols)
        let newW = max(step, min(Double(frame.w), Double(rect.w) + step * Double(deltaCols)))
        let target = WMRect(x: Double(rect.x), y: Double(rect.y), w: newW, h: Double(rect.h))
        return clamp(rect: target, frame: frame)
    }

    /// Grow/shrink height by one grid row, anchored on top edge.
    public static func resizeHeight(rect: WMRect, frame: WMRect, deltaRows: Int, rows: Int = 8) -> WMRect {
        let step = Double(frame.h) / Double(rows)
        let newH = max(step, min(Double(frame.h), Double(rect.h) + step * Double(deltaRows)))
        let target = WMRect(x: Double(rect.x), y: Double(rect.y), w: Double(rect.w), h: newH)
        return clamp(rect: target, frame: frame)
    }

    // MARK: - Containment & screen detection

    /// Test if `rect` is fully inside `frame` (inclusive edges).
    public static func contains(frame: WMRect, rect: WMRect) -> Bool {
        rect.x >= frame.x &&
        rect.y >= frame.y &&
        rect.x + rect.w <= frame.x + frame.w &&
        rect.y + rect.h <= frame.y + frame.h
    }

    /// Return the screen index whose frame contains the largest overlap with `rect`.
    public static func screenForRect(screens: [ScreenInfo], rect: WMRect) -> Int? {
        var bestIdx: Int? = nil
        var bestArea: Int = -1
        for (i, s) in screens.enumerated() {
            let fx1 = s.frame.x
            let fy1 = s.frame.y
            let fx2 = s.frame.x + s.frame.w
            let fy2 = s.frame.y + s.frame.h
            let rx1 = rect.x
            let ry1 = rect.y
            let rx2 = rect.x + rect.w
            let ry2 = rect.y + rect.h
            let ox = max(0, min(fx2, rx2) - max(fx1, rx1))
            let oy = max(0, min(fy2, ry2) - max(fy1, ry1))
            let area = ox * oy
            if area > bestArea {
                bestArea = area
                bestIdx = i
            }
        }
        return bestIdx
    }
}
