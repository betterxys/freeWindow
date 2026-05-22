// PinnedImageWindow.swift — Floating, draggable window displaying a pinned screenshot.

import AppKit

final class PinnedImageWindow: NSWindow {
    private let pinnedId: UUID
    private let onClose: (UUID) -> Void
    private var escMonitor: Any?

    init(image: NSImage, frame: NSRect, id: UUID, onClose: @escaping (UUID) -> Void) {
        self.pinnedId = id
        self.onClose = onClose

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false

        // Content view with image + close button
        let containerView = PinnedImageView(image: image) { [weak self] in
            guard let self = self else { return }
            self.onClose(self.pinnedId)
        }
        self.contentView = containerView

        // Esc to close this pin
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isKeyWindow else { return event }
            if event.keyCode == 53 { // Escape
                self.onClose(self.pinnedId)
                return nil
            }
            return event
        }
    }

    func show() {
        self.orderFrontRegardless()
    }

    override func close() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
        self.orderOut(nil)
    }
}

/// NSView that displays the pinned image with a close button on hover.
final class PinnedImageView: NSView {
    private let imageView: NSImageView
    private let closeButton: NSButton
    private let onClose: () -> Void
    private var trackingArea: NSTrackingArea?

    init(image: NSImage, onClose: @escaping () -> Void) {
        self.onClose = onClose

        imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown

        closeButton = NSButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        closeButton.bezelStyle = .circular
        if let img = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close") {
            closeButton.image = img
        } else {
            closeButton.title = "✕"
        }
        closeButton.isBordered = false
        closeButton.isHidden = true

        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.systemGray.withAlphaComponent(0.3).cgColor

        addSubview(imageView)
        addSubview(closeButton)

        closeButton.target = self
        closeButton.action = #selector(closeClicked)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        closeButton.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        closeButton.isHidden = true
    }

    @objc private func closeClicked() {
        onClose()
    }
}
