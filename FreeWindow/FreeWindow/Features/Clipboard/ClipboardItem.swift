// ClipboardItem.swift — Model for clipboard history entries.

import AppKit

/// Represents a single item in clipboard history.
struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    let sourceApp: String?

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// The actual content of a clipboard item.
enum ClipboardContent: Equatable {
    case text(String)
    case attributedText(NSAttributedString)
    case image(NSImage)
    case fileURLs([URL])

    /// Preview text for display in the popup list.
    var preview: String {
        switch self {
        case .text(let str):
            return String(str.prefix(100))
        case .attributedText(let attrStr):
            return String(attrStr.string.prefix(100))
        case .image:
            return "[Image]"
        case .fileURLs(let urls):
            return urls.map(\.lastPathComponent).joined(separator: ", ")
        }
    }

    /// Icon for the content type.
    var iconName: String {
        switch self {
        case .text, .attributedText: return "doc.text"
        case .image: return "photo"
        case .fileURLs: return "doc.on.doc"
        }
    }

    static func == (lhs: ClipboardContent, rhs: ClipboardContent) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)): return a == b
        case (.image, .image): return false // Images can't be cheaply compared
        case (.fileURLs(let a), .fileURLs(let b)): return a == b
        default: return false
        }
    }
}
