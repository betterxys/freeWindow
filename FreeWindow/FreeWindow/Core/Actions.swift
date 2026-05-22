// Actions.swift — High-level window actions as pure functions.
// Direct port of modules/actions.lua.
// Every action takes an ActionContext and returns a WMRect (or nil for no-op).

import Foundation

/// The world state needed by actions. Built by the coordinator before each action.
public struct ActionContext {
    public let windowFrame: WMRect
    public let screenIndex: Int       // 0-based index into screens
    public let screens: [ScreenInfo]
    public let resolver: ScreenResolver
    public let grid: Grid

    public init(windowFrame: WMRect, screenIndex: Int, screens: [ScreenInfo], resolver: ScreenResolver, grid: Grid) {
        self.windowFrame = windowFrame
        self.screenIndex = screenIndex
        self.screens = screens
        self.resolver = resolver
        self.grid = grid
    }

    public var currentFrame: WMRect {
        screens[screenIndex].frame
    }
}

public enum Actions {

    // MARK: - Halves & Quadrants

    public static func leftHalf(_ ctx: ActionContext) -> WMRect {
        Geometry.half(frame: ctx.currentFrame, .left)
    }
    public static func rightHalf(_ ctx: ActionContext) -> WMRect {
        Geometry.half(frame: ctx.currentFrame, .right)
    }
    public static func topHalf(_ ctx: ActionContext) -> WMRect {
        Geometry.half(frame: ctx.currentFrame, .top)
    }
    public static func bottomHalf(_ ctx: ActionContext) -> WMRect {
        Geometry.half(frame: ctx.currentFrame, .bottom)
    }

    public static func quadrantNW(_ ctx: ActionContext) -> WMRect {
        Geometry.quadrant(frame: ctx.currentFrame, .nw)
    }
    public static func quadrantNE(_ ctx: ActionContext) -> WMRect {
        Geometry.quadrant(frame: ctx.currentFrame, .ne)
    }
    public static func quadrantSW(_ ctx: ActionContext) -> WMRect {
        Geometry.quadrant(frame: ctx.currentFrame, .sw)
    }
    public static func quadrantSE(_ ctx: ActionContext) -> WMRect {
        Geometry.quadrant(frame: ctx.currentFrame, .se)
    }

    // MARK: - Maximize & Center

    public static func maximize(_ ctx: ActionContext) -> WMRect {
        Geometry.maximize(frame: ctx.currentFrame)
    }

    public static func center(_ ctx: ActionContext) -> WMRect {
        Geometry.centered(frame: ctx.currentFrame, rect: ctx.windowFrame)
    }

    // MARK: - Thirds

    public static func thirdLeft(_ ctx: ActionContext) -> WMRect {
        Geometry.third(frame: ctx.currentFrame, .left)
    }
    public static func thirdCenter(_ ctx: ActionContext) -> WMRect {
        Geometry.third(frame: ctx.currentFrame, .center)
    }
    public static func thirdRight(_ ctx: ActionContext) -> WMRect {
        Geometry.third(frame: ctx.currentFrame, .right)
    }
    public static func twoThirdsLeft(_ ctx: ActionContext) -> WMRect {
        Geometry.twoThirds(frame: ctx.currentFrame, .left)
    }
    public static func twoThirdsRight(_ ctx: ActionContext) -> WMRect {
        Geometry.twoThirds(frame: ctx.currentFrame, .right)
    }

    // MARK: - 3×3 Grid

    /// Cells numbered 1..9 row-major: 1=NW, 5=center, 9=SE.
    public static func grid3x3(_ ctx: ActionContext, cell: Int) -> WMRect {
        precondition(cell >= 1 && cell <= 9, "cell must be in 1..9")
        let col = ((cell - 1) % 3) + 1
        let row = ((cell - 1) / 3) + 1
        return Geometry.gridCell(frame: ctx.currentFrame, cols: 3, rows: 3, col: col, row: row)
    }

    // MARK: - Nudge & Resize

    public static func nudge(_ ctx: ActionContext, direction: Direction) -> WMRect {
        Geometry.nudge(rect: ctx.windowFrame, frame: ctx.currentFrame,
                       direction: direction, cols: ctx.grid.cols, rows: ctx.grid.rows)
    }

    public static func wider(_ ctx: ActionContext) -> WMRect {
        Geometry.resizeWidth(rect: ctx.windowFrame, frame: ctx.currentFrame,
                            deltaCols: 1, cols: ctx.grid.cols)
    }
    public static func narrower(_ ctx: ActionContext) -> WMRect {
        Geometry.resizeWidth(rect: ctx.windowFrame, frame: ctx.currentFrame,
                            deltaCols: -1, cols: ctx.grid.cols)
    }
    public static func taller(_ ctx: ActionContext) -> WMRect {
        Geometry.resizeHeight(rect: ctx.windowFrame, frame: ctx.currentFrame,
                             deltaRows: 1, rows: ctx.grid.rows)
    }
    public static func shorter(_ ctx: ActionContext) -> WMRect {
        Geometry.resizeHeight(rect: ctx.windowFrame, frame: ctx.currentFrame,
                             deltaRows: -1, rows: ctx.grid.rows)
    }

    // MARK: - Cross-screen

    /// Send window to screen at `targetIndex` (0-based), preserving relative position.
    /// Returns nil if target is missing or same as current.
    public static func sendToScreen(_ ctx: ActionContext, targetIndex: Int, mode: MoveMode = .ratios) -> WMRect? {
        guard targetIndex != ctx.screenIndex,
              targetIndex >= 0, targetIndex < ctx.screens.count else { return nil }
        let from = ctx.screens[ctx.screenIndex].frame
        let to = ctx.screens[targetIndex].frame
        return Geometry.moveToScreen(rect: ctx.windowFrame, from: from, to: to, mode: mode)
    }

    /// Send to a named role (e.g. "left", "main", "right").
    public static func sendToRole(_ ctx: ActionContext, role: String, mode: MoveMode = .ratios) -> WMRect? {
        guard let idx = ctx.resolver.indexForRole(role) else { return nil }
        return sendToScreen(ctx, targetIndex: idx, mode: mode)
    }

    /// Send to next/previous screen (cycling).
    public static func sendToNextScreen(_ ctx: ActionContext, step: Int = 1, mode: MoveMode = .ratios) -> WMRect? {
        guard let idx = ctx.resolver.nextIndex(from: ctx.screenIndex, step: step),
              idx != ctx.screenIndex else { return nil }
        return sendToScreen(ctx, targetIndex: idx, mode: mode)
    }
}
