// HotkeyBindings.swift — Declarative hotkey binding table + conflict detection.
// Direct port of modules/hotkeys.lua.

import Foundation
import Carbon.HIToolbox

/// Represents a single hotkey binding.
public struct HotkeyBinding {
    public let modifiers: Set<HotkeyModifier>
    public let key: String              // Key name (e.g. "h", "return", "left", "1")
    public let name: String             // Unique action name
    public let action: (ActionContext) -> WMRect?

    public init(modifiers: Set<HotkeyModifier>, key: String, name: String, action: @escaping (ActionContext) -> WMRect?) {
        self.modifiers = modifiers; self.key = key; self.name = name; self.action = action
    }
}

public enum HotkeyModifier: String, Hashable, CaseIterable {
    case ctrl, alt, cmd, shift
}

/// A conflict: multiple bindings share the same (mods, key) pair.
public struct HotkeyConflict {
    public let modifiers: Set<HotkeyModifier>
    public let key: String
    public let names: [String]
}

public enum HotkeyBindings {
    public static let defaultHyper: Set<HotkeyModifier> = [.ctrl, .alt, .cmd]
    public static let defaultHyperShift: Set<HotkeyModifier> = [.ctrl, .alt, .cmd, .shift]

    /// Build the complete binding list.
    public static func build(
        hyper: Set<HotkeyModifier> = defaultHyper,
        hyperShift: Set<HotkeyModifier> = defaultHyperShift
    ) -> [HotkeyBinding] {
        var b: [HotkeyBinding] = []

        func bind(_ mods: Set<HotkeyModifier>, _ key: String, _ name: String,
                  _ action: @escaping (ActionContext) -> WMRect?) {
            b.append(HotkeyBinding(modifiers: mods, key: key, name: name, action: action))
        }

        // Halves
        bind(hyper, "h", "left_half")   { Actions.leftHalf($0)   }
        bind(hyper, "l", "right_half")  { Actions.rightHalf($0)  }
        bind(hyper, "k", "top_half")    { Actions.topHalf($0)    }
        bind(hyper, "j", "bottom_half") { Actions.bottomHalf($0) }

        // Quadrants
        bind(hyper, "u", "quadrant_nw") { Actions.quadrantNW($0) }
        bind(hyper, "i", "quadrant_ne") { Actions.quadrantNE($0) }
        bind(hyper, "n", "quadrant_sw") { Actions.quadrantSW($0) }
        bind(hyper, "m", "quadrant_se") { Actions.quadrantSE($0) }

        // Maximize, center
        bind(hyper, "return", "maximize") { Actions.maximize($0) }
        bind(hyper, "c", "center")        { Actions.center($0)   }

        // Thirds
        bind(hyperShift, "h", "third_left")       { Actions.thirdLeft($0)      }
        bind(hyperShift, "j", "third_center")     { Actions.thirdCenter($0)    }
        bind(hyperShift, "l", "third_right")      { Actions.thirdRight($0)     }
        bind(hyperShift, "u", "two_thirds_left")  { Actions.twoThirdsLeft($0)  }
        bind(hyperShift, "o", "two_thirds_right") { Actions.twoThirdsRight($0) }

        // Nudge
        bind(hyper, "left",  "nudge_left")  { Actions.nudge($0, direction: .left)  }
        bind(hyper, "right", "nudge_right") { Actions.nudge($0, direction: .right) }
        bind(hyper, "up",    "nudge_up")    { Actions.nudge($0, direction: .up)    }
        bind(hyper, "down",  "nudge_down")  { Actions.nudge($0, direction: .down)  }

        // Resize
        bind(hyper,      "]", "wider")    { Actions.wider($0)    }
        bind(hyper,      "[", "narrower") { Actions.narrower($0) }
        bind(hyperShift, "]", "taller")   { Actions.taller($0)   }
        bind(hyperShift, "[", "shorter")  { Actions.shorter($0)  }

        // 3×3 grid (hyper_shift + 1..9)
        for cell in 1...9 {
            bind(hyperShift, "\(cell)", "grid3x3_\(cell)") { ctx in
                Actions.grid3x3(ctx, cell: cell)
            }
        }

        // Send to absolute screen 1..3 (hyper + 1/2/3) — 0-based internally
        for idx in 1...3 {
            bind(hyper, "\(idx)", "send_to_screen_\(idx)") { ctx in
                Actions.sendToScreen(ctx, targetIndex: idx - 1, mode: .ratios)
            }
        }

        // Cycle screens
        bind(hyper, ",", "send_prev_screen") { ctx in
            Actions.sendToNextScreen(ctx, step: -1, mode: .ratios)
        }
        bind(hyper, ".", "send_next_screen") { ctx in
            Actions.sendToNextScreen(ctx, step: 1, mode: .ratios)
        }

        return b
    }

    /// Detect duplicate (mods, key) pairs in a binding list.
    public static func detectConflicts(_ bindings: [HotkeyBinding]) -> [HotkeyConflict] {
        var seen: [String: (modifiers: Set<HotkeyModifier>, key: String, names: [String])] = [:]

        for bnd in bindings {
            let sig = signature(modifiers: bnd.modifiers, key: bnd.key)
            if var entry = seen[sig] {
                entry.names.append(bnd.name)
                seen[sig] = entry
            } else {
                seen[sig] = (modifiers: bnd.modifiers, key: bnd.key, names: [bnd.name])
            }
        }

        return seen.values
            .filter { $0.names.count > 1 }
            .map { HotkeyConflict(modifiers: $0.modifiers, key: $0.key, names: $0.names) }
    }

    /// Canonical signature for a (mods, key) combo.
    public static func signature(modifiers: Set<HotkeyModifier>, key: String) -> String {
        let modsStr = modifiers.map(\.rawValue).sorted().joined(separator: "+")
        return "\(modsStr)/\(key.lowercased())"
    }
}
