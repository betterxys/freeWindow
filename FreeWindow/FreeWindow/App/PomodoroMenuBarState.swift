// PomodoroMenuBarState.swift — Observable state for the menu bar timer label.

import SwiftUI
import FreeWindowCore

final class PomodoroMenuBarState: ObservableObject {
    static let shared = PomodoroMenuBarState()

    /// Compact timer label shown in the menu bar. `nil` when idle.
    @Published private(set) var label: String?
    /// Fuller status line shown in the dropdown menu.
    @Published private(set) var detailText: String = "番茄钟: 待启动"

    var isActive: Bool { label != nil }

    func refresh(from controller: PomodoroController) {
        label = controller.menuBarLabel()
        detailText = controller.summary()
    }
}
