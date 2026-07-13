// BreakReminderService.swift — Large phase-boundary reminders (work end / rest end).

import SwiftUI
import AppKit
import FreeWindowCore

private struct ReminderContent {
    let emoji: String
    let title: String
    let subtitle: String
    let countdownSuffix: String
    let primaryLabel: String
    let secondaryLabel: String
    let tertiaryLabel: String?
}

final class BreakReminderService {
    static let shared = BreakReminderService()

    private var panel: NSPanel?
    private var backdrop: NSWindow?
    private var countdownTimer: Timer?
    private var primaryAction: (() -> Void)?
    private var secondaryAction: (() -> Void)?
    private var tertiaryAction: (() -> Void)?
    private var model: BreakReminderModel?

    func showWorkComplete(
        restDuration: TimeInterval,
        warningSeconds: TimeInterval,
        discipline: BreakDiscipline,
        snoozeSeconds: TimeInterval,
        completion: @escaping (WorkCompleteDecision) -> Void
    ) {
        let strict = discipline == .strict
        present(
            content: ReminderContent(
                emoji: "🍅",
                title: "工作完成！",
                subtitle: strict
                    ? "严格模式：建议息屏休息 \(formatMinutes(restDuration))"
                    : "建议休息 \(formatMinutes(restDuration))",
                countdownSuffix: "秒",
                primaryLabel: strict ? "休息并息屏" : "开始休息",
                secondaryLabel: "推迟 \(formatMinutes(snoozeSeconds))",
                tertiaryLabel: "跳过一次"
            ),
            warningSeconds: warningSeconds,
            onPrimary: { completion(.takeBreak) },
            onSecondary: { completion(.snooze) },
            onTertiary: { completion(.skip) }
        )
    }

    func showRestEnded(
        workDuration: TimeInterval,
        warningSeconds: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) {
        present(
            content: ReminderContent(
                emoji: "☕",
                title: "休息结束！",
                subtitle: "下一工作周期 \(formatMinutes(workDuration))",
                countdownSuffix: "秒",
                primaryLabel: "开始工作",
                secondaryLabel: "继续休息",
                tertiaryLabel: nil
            ),
            warningSeconds: warningSeconds,
            onPrimary: { completion(true) },
            onSecondary: { completion(false) },
            onTertiary: nil
        )
    }

    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            self?.tearDown(callCompletion: false)
        }
    }

    private func present(
        content: ReminderContent,
        warningSeconds: TimeInterval,
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void,
        onTertiary: (() -> Void)?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.presentOnMain(
                content: content,
                warningSeconds: warningSeconds,
                onPrimary: onPrimary,
                onSecondary: onSecondary,
                onTertiary: onTertiary
            )
        }
    }

    private func presentOnMain(
        content: ReminderContent,
        warningSeconds: TimeInterval,
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void,
        onTertiary: (() -> Void)?
    ) {
        tearDown(callCompletion: false)
        primaryAction = onPrimary
        secondaryAction = onSecondary
        tertiaryAction = onTertiary

        let reminder = BreakReminderModel(seconds: max(1, Int(warningSeconds.rounded())))
        model = reminder

        let hosting = NSHostingView(
            rootView: PhaseReminderView(
                content: content,
                model: reminder,
                onPrimary: { [weak self] in self?.finish(.primary) },
                onSecondary: { [weak self] in self?.finish(.secondary) },
                onTertiary: { [weak self] in self?.finish(.tertiary) }
            )
        )
        let size = NSSize(width: 440, height: 400)
        hosting.frame = NSRect(origin: .zero, size: size)

        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame

        let backdrop = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        backdrop.backgroundColor = NSColor.black.withAlphaComponent(0.45)
        backdrop.level = .modalPanel
        backdrop.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backdrop.isOpaque = false
        backdrop.ignoresMouseEvents = true
        self.backdrop = backdrop
        backdrop.orderFrontRegardless()

        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "FreeWindow"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true
        panel.level = .modalPanel + 1
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .windowBackgroundColor
        panel.contentView = hosting
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self, let model = self.model else {
                timer.invalidate()
                return
            }
            if model.waitingForChoice { return }
            model.secondsLeft -= 1
            if model.secondsLeft <= 0 {
                model.secondsLeft = 0
                model.waitingForChoice = true
                timer.invalidate()
                // Drop the full-screen dim once we're only waiting for a choice.
                // Otherwise an away user (e.g. overnight) comes back to a gray
                // screen that lingers until the pomodoro is cancelled.
                self.backdrop?.orderOut(nil)
                self.backdrop = nil
            }
        }
    }

    private enum ReminderButton {
        case primary, secondary, tertiary
    }

    private func finish(_ button: ReminderButton) {
        let primary = primaryAction
        let secondary = secondaryAction
        let tertiary = tertiaryAction
        tearDown(callCompletion: false)
        switch button {
        case .primary: primary?()
        case .secondary: secondary?()
        case .tertiary: tertiary?()
        }
    }

    private func tearDown(callCompletion: Bool) {
        countdownTimer?.invalidate()
        countdownTimer = nil
        panel?.orderOut(nil)
        panel = nil
        backdrop?.orderOut(nil)
        backdrop = nil
        model = nil
        if callCompletion {
            secondaryAction?()
        }
        primaryAction = nil
        secondaryAction = nil
        tertiaryAction = nil
    }

    private func formatMinutes(_ seconds: TimeInterval) -> String {
        let mins = max(1, Int((seconds / 60).rounded()))
        return "\(mins) 分钟"
    }
}

private final class BreakReminderModel: ObservableObject {
    @Published var secondsLeft: Int
    @Published var waitingForChoice = false
    init(seconds: Int) { secondsLeft = seconds }
}

private struct PhaseReminderView: View {
    let content: ReminderContent
    @ObservedObject var model: BreakReminderModel
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    let onTertiary: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(content.emoji)
                .font(.system(size: 64))
            Text(content.title)
                .font(.system(size: 32, weight: .bold))
            Text(content.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("\(model.secondsLeft)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: model.secondsLeft)

            Text(model.waitingForChoice ? "请选择下方操作" : content.countdownSuffix)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                if let tertiary = content.tertiaryLabel {
                    Button(tertiary, action: onTertiary)
                        .controlSize(.large)
                }
                Button(content.secondaryLabel, action: onSecondary)
                    .controlSize(.large)
                Button(content.primaryLabel, action: onPrimary)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
