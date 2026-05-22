// ClipboardPopupView.swift — SwiftUI popup for clipboard history selection.
// Supports keyboard navigation: ↑/↓ to select, Enter to paste, Esc to close.

import SwiftUI

struct ClipboardPopupView: View {
    @ObservedObject var manager: ClipboardManager
    @State private var searchText = ""
    @State private var selectedIndex = 0

    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return manager.history
        }
        return manager.history.filter { item in
            item.content.preview.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search clipboard history...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit {
                        pasteSelected()
                    }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Items list
            if filteredItems.isEmpty {
                VStack {
                    Spacer()
                    Text("No items")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    List(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(item: item, isSelected: index == selectedIndex)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                manager.paste(item: item)
                            }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { newIndex in
                        if newIndex >= 0 && newIndex < filteredItems.count {
                            proxy.scrollTo(filteredItems[newIndex].id, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Text("\(manager.history.count) items")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("↑↓ select · ↩ paste · Esc close")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 350, minHeight: 300)
        .background(KeyboardHandlerView(
            onUp: { moveSelection(-1) },
            onDown: { moveSelection(1) },
            onEnter: { pasteSelected() },
            onEscape: { manager.hidePopup() }
        ))
    }

    private func moveSelection(_ delta: Int) {
        let count = filteredItems.count
        guard count > 0 else { return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
    }

    private func pasteSelected() {
        guard selectedIndex >= 0 && selectedIndex < filteredItems.count else { return }
        manager.paste(item: filteredItems[selectedIndex])
    }
}

/// NSViewRepresentable that captures keyboard events for the popup.
struct KeyboardHandlerView: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onUp = onUp
        view.onDown = onDown
        view.onEnter = onEnter
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onUp = onUp
        nsView.onDown = onDown
        nsView.onEnter = onEnter
        nsView.onEscape = onEscape
    }
}

/// NSView subclass that monitors key events at the window level.
class KeyCaptureNSView: NSView {
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?

    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }
                switch event.keyCode {
                case 126: // Up arrow
                    self.onUp?()
                    return nil
                case 125: // Down arrow
                    self.onDown?()
                    return nil
                case 36: // Return
                    self.onEnter?()
                    return nil
                case 53: // Escape
                    self.onEscape?()
                    return nil
                default:
                    return event
                }
            }
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil, let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.content.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.content.preview)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    if let app = item.sourceApp {
                        Text(app)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Text(item.timestamp, style: .relative)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Image thumbnail
            if case .image(let img) = item.content {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 30)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
}
