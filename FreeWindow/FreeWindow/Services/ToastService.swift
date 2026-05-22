import FreeWindowCore
// ToastService.swift — Ephemeral floating notification (replaces hs.alert).
// Shows a small dark toast that auto-dismisses after a short duration.

import AppKit

final class ToastService {
    static let shared = ToastService()

    private var toastWindow: NSWindow?
    private var dismissTimer: Timer?
    private static let duration: TimeInterval = 0.75

    /// Show a brief toast notification on the main screen.
    func show(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss()
            self?.createAndShow(message)
        }
    }

    private func createAndShow(_ message: String) {
        guard let mainScreen = NSScreen.main else { return }

        let padding: CGFloat = 14
        let font = NSFont.systemFont(ofSize: 14, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (message as NSString).size(withAttributes: attributes)
        let windowWidth = textSize.width + padding * 2 + 10
        let windowHeight = textSize.height + padding + 6

        let screenFrame = mainScreen.visibleFrame
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.midY - windowHeight / 2

        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor(white: 0, alpha: 0.6)
        window.hasShadow = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 6

        let textField = NSTextField(labelWithString: message)
        textField.font = font
        textField.textColor = NSColor(white: 1, alpha: 0.9)
        textField.alignment = .center
        textField.frame = NSRect(x: padding, y: 3, width: textSize.width + 10, height: textSize.height)
        window.contentView?.addSubview(textField)

        window.orderFrontRegardless()
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            window.animator().alphaValue = 1
        }

        toastWindow = window

        dismissTimer = Timer.scheduledTimer(withTimeInterval: Self.duration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        if let window = toastWindow {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.15
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
            })
        }
        toastWindow = nil
    }
}
