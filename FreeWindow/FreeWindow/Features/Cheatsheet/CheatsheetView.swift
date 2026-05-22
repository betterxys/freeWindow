import FreeWindowCore
// CheatsheetView.swift — SwiftUI content for the cheatsheet panel.
// 3-column grid layout with categorized hotkey bindings.

import SwiftUI

struct CheatsheetView: View {
    private let categories = CheatsheetData.categories

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("⌨ Hotkey Cheatsheet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 200), spacing: 22),
                GridItem(.flexible(minimum: 200), spacing: 22),
                GridItem(.flexible(minimum: 200), spacing: 22),
            ], alignment: .leading, spacing: 12) {
                ForEach(categories) { cat in
                    CategorySection(category: cat)
                }
            }

            Spacer()

            Text("Press Esc or ⌃⌥⌘/ to dismiss")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .frame(minWidth: 780, minHeight: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct CategorySection: View {
    let category: CheatsheetCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.name.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)

            ForEach(category.items) { item in
                HStack {
                    Text(item.label)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(item.shortcut)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "FFD60A"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                }
            }
        }
    }
}

// MARK: - Data

struct CheatsheetItem: Identifiable {
    let id = UUID()
    let label: String
    let shortcut: String
}

struct CheatsheetCategory: Identifiable {
    let id = UUID()
    let name: String
    let items: [CheatsheetItem]
}

enum CheatsheetData {
    static let categories: [CheatsheetCategory] = [
        CheatsheetCategory(name: "Halves", items: [
            CheatsheetItem(label: "Left Half", shortcut: "⌃⌥⌘H"),
            CheatsheetItem(label: "Right Half", shortcut: "⌃⌥⌘L"),
            CheatsheetItem(label: "Top Half", shortcut: "⌃⌥⌘K"),
            CheatsheetItem(label: "Bottom Half", shortcut: "⌃⌥⌘J"),
        ]),
        CheatsheetCategory(name: "Quadrants", items: [
            CheatsheetItem(label: "NW", shortcut: "⌃⌥⌘U"),
            CheatsheetItem(label: "NE", shortcut: "⌃⌥⌘I"),
            CheatsheetItem(label: "SW", shortcut: "⌃⌥⌘N"),
            CheatsheetItem(label: "SE", shortcut: "⌃⌥⌘M"),
        ]),
        CheatsheetCategory(name: "Center / Max", items: [
            CheatsheetItem(label: "Maximize", shortcut: "⌃⌥⌘↩"),
            CheatsheetItem(label: "Center", shortcut: "⌃⌥⌘C"),
        ]),
        CheatsheetCategory(name: "Thirds", items: [
            CheatsheetItem(label: "Left Third", shortcut: "⌃⌥⌘⇧H"),
            CheatsheetItem(label: "Center Third", shortcut: "⌃⌥⌘⇧J"),
            CheatsheetItem(label: "Right Third", shortcut: "⌃⌥⌘⇧L"),
            CheatsheetItem(label: "Left ⅔", shortcut: "⌃⌥⌘⇧U"),
            CheatsheetItem(label: "Right ⅔", shortcut: "⌃⌥⌘⇧O"),
        ]),
        CheatsheetCategory(name: "Nudge", items: [
            CheatsheetItem(label: "Nudge ←", shortcut: "⌃⌥⌘←"),
            CheatsheetItem(label: "Nudge →", shortcut: "⌃⌥⌘→"),
            CheatsheetItem(label: "Nudge ↑", shortcut: "⌃⌥⌘↑"),
            CheatsheetItem(label: "Nudge ↓", shortcut: "⌃⌥⌘↓"),
        ]),
        CheatsheetCategory(name: "Resize", items: [
            CheatsheetItem(label: "Wider", shortcut: "⌃⌥⌘]"),
            CheatsheetItem(label: "Narrower", shortcut: "⌃⌥⌘["),
            CheatsheetItem(label: "Taller", shortcut: "⌃⌥⌘⇧]"),
            CheatsheetItem(label: "Shorter", shortcut: "⌃⌥⌘⇧["),
        ]),
        CheatsheetCategory(name: "3×3 Grid", items: [
            CheatsheetItem(label: "Cells 1–9", shortcut: "⌃⌥⌘⇧1–9"),
        ]),
        CheatsheetCategory(name: "Screen", items: [
            CheatsheetItem(label: "Screen 1/2/3", shortcut: "⌃⌥⌘1/2/3"),
            CheatsheetItem(label: "← Prev Screen", shortcut: "⌃⌥⌘,"),
            CheatsheetItem(label: "Next Screen →", shortcut: "⌃⌥⌘."),
        ]),
        CheatsheetCategory(name: "Layout & More", items: [
            CheatsheetItem(label: "Save Layout", shortcut: "⌃⌥⌘S"),
            CheatsheetItem(label: "Restore Layout", shortcut: "⌃⌥⌘R"),
            CheatsheetItem(label: "Clipboard History", shortcut: "⌃⌥⌘V"),
            CheatsheetItem(label: "Screenshot Pin", shortcut: "⌃⌥⌘P"),
            CheatsheetItem(label: "Remove All Pins", shortcut: "⌃⌥⌘⇧P"),
            CheatsheetItem(label: "This Cheatsheet", shortcut: "⌃⌥⌘/"),
        ]),
    ]
}

// MARK: - Helpers

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
