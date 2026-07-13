// PomodoroController.swift — Glues the pure pomodoro state machine to the
// wall clock, the toast UI, the busy detector and the screen-lock effect.
//
// Mirrors the Lua `pomodoro_controller` module. Everything that touches
// the system goes through `PomodoroDriver`, which the tests stub out with
// a fake clock and a spy lock implementation.

import Foundation

/// Configurable knobs (all defaults match `PomodoroConfig` for phase
/// durations).
public struct PomodoroSettings {
    public var phases: PomodoroConfig
    public var lockMode: ScreenLockMode
    public var breakDiscipline: BreakDiscipline
    public var breakSnoozeSeconds: TimeInterval
    public var busyKeywords: [String]
    public var busyGraceSeconds: TimeInterval
    public var busyMaxRetries: Int          // additional attempts after the first
    public var tickInterval: TimeInterval
    /// Seconds to show the break reminder before auto sleep. 0 = sleep immediately.
    public var lockWarningSeconds: TimeInterval

    public init(
        phases: PomodoroConfig = PomodoroConfig(),
        lockMode: ScreenLockMode = .displaysSleep,
        breakDiscipline: BreakDiscipline = .gentle,
        breakSnoozeSeconds: TimeInterval = 5 * 60,
        busyKeywords: [String] = BusyDetect.defaultBusyKeywords,
        busyGraceSeconds: TimeInterval = 60,
        busyMaxRetries: Int = 3,
        tickInterval: TimeInterval = 1.0,
        lockWarningSeconds: TimeInterval = 10
    ) {
        self.phases = phases
        self.lockMode = lockMode
        self.breakDiscipline = breakDiscipline
        self.breakSnoozeSeconds = breakSnoozeSeconds
        self.busyKeywords = busyKeywords
        self.busyGraceSeconds = busyGraceSeconds
        self.busyMaxRetries = busyMaxRetries
        self.tickInterval = tickInterval
        self.lockWarningSeconds = lockWarningSeconds
    }
}

public enum BreakDiscipline: String, Equatable {
    case gentle
    case firm
    case strict
}

public enum WorkCompleteDecision: Equatable {
    case takeBreak
    case snooze
    case skip
}

/// Minimal handle we need from a driver-supplied timer.
public protocol PomodoroTimerHandle: AnyObject {
    func stop()
}

/// Everything the controller needs from "the world". The default impl
/// (`SystemPomodoroDriver`) wires this up to real timers, ScreenLockService,
/// BusySignalCollector and ToastService. Tests inject a fake.
public protocol PomodoroDriver: AnyObject {
    func now() -> TimeInterval
    func every(_ interval: TimeInterval, _ fn: @escaping () -> Void) -> PomodoroTimerHandle
    func after(_ delay: TimeInterval, _ fn: @escaping () -> Void) -> PomodoroTimerHandle
    func collectBusySignals() -> BusySignals
    func putScreenOff(_ mode: ScreenLockMode) -> Bool
    func notify(_ message: String)
    /// Show a break reminder before sleeping the display. Call `completion(true)`
    /// to proceed with lock, `completion(false)` to skip.
    func promptBreakBeforeLock(
        restDuration: TimeInterval,
        warningSeconds: TimeInterval,
        discipline: BreakDiscipline,
        snoozeSeconds: TimeInterval,
        completion: @escaping (WorkCompleteDecision) -> Void
    )
    /// Rest phase ended — ask whether to start work or continue resting.
    /// `completion(true)` → start work; `completion(false)` → continue rest.
    func promptRestEnded(
        workDuration: TimeInterval,
        warningSeconds: TimeInterval,
        completion: @escaping (Bool) -> Void
    )
    /// Tear down any on-screen break reminder overlay (gray backdrop + panel).
    /// Safe to call when nothing is showing.
    func dismissBreakReminder()
}

public final class PomodoroController {
    public private(set) var state: PomodoroState
    public var settings: PomodoroSettings
    private let driver: PomodoroDriver

    /// Fired after every state change and on each tick while a phase is running.
    public var onUpdate: (() -> Void)?

    private var tickTimer: PomodoroTimerHandle?
    /// Tracks deferred-lock retry state when we hit a "busy" verdict at a
    /// work-phase boundary.
    private var pendingLockAttempts: Int?

    public init(settings: PomodoroSettings = PomodoroSettings(), driver: PomodoroDriver) {
        self.settings = settings
        self.driver = driver
        self.state = PomodoroState(config: settings.phases)
    }

    // MARK: - User commands

    public func start() {
        guard state.phase == .idle else { return }
        driver.dismissBreakReminder()
        applyStep(Pomodoro.start(state, now: driver.now()))
        ensureTimer()
    }

    public func pause() {
        guard state.phase != .idle, state.phase != .paused else { return }
        driver.dismissBreakReminder()
        applyStep(Pomodoro.pause(state, now: driver.now()))
    }

    public func resume() {
        guard state.phase == .paused else { return }
        driver.dismissBreakReminder()
        applyStep(Pomodoro.resume(state, now: driver.now()))
        ensureTimer()
    }

    public func toggle() {
        switch state.phase {
        case .idle:   start()
        case .paused: resume()
        default:      pause()
        }
    }

    public func skip() {
        driver.dismissBreakReminder()
        applyStep(Pomodoro.skip(state, now: driver.now()))
    }

    public func cancel() {
        driver.dismissBreakReminder()
        applyStep(Pomodoro.cancel(state))
        clearTimer()
        pendingLockAttempts = nil
    }

    // MARK: - Public introspection

    public struct Status {
        public let phase: PomodoroPhase
        public let pausedPhase: PomodoroPhase?
        public let remainingSeconds: TimeInterval
        public let elapsedSeconds: TimeInterval
        public let completedWorkCycles: Int
        public let pendingLock: Bool
    }

    public func status() -> Status {
        let now = driver.now()
        return Status(
            phase: state.phase,
            pausedPhase: state.pausedPhase,
            remainingSeconds: Pomodoro.remaining(state, now: now),
            elapsedSeconds: Pomodoro.elapsed(state, now: now),
            completedWorkCycles: state.completedWorkCycles,
            pendingLock: pendingLockAttempts != nil
        )
    }

    public func summary() -> String {
        switch state.phase {
        case .idle:
            return "番茄钟: 待启动"
        case .paused:
            let p = state.pausedPhase.map(formatPhase) ?? "—"
            return "番茄钟: 已暂停 (\(p)) · \(formatRemaining(Pomodoro.remaining(state, now: driver.now())))"
        default:
            let rem = Pomodoro.remaining(state, now: driver.now())
            return "\(formatPhase(state.phase)) · \(formatRemaining(rem))"
        }
    }

    /// Compact label for the menu bar. `nil` when idle.
    public func menuBarLabel() -> String? {
        switch state.phase {
        case .idle:
            return nil
        case .paused:
            return "⏸ \(formatRemaining(Pomodoro.remaining(state, now: driver.now())))"
        default:
            return "\(phaseEmoji(state.phase)) \(formatRemaining(Pomodoro.remaining(state, now: driver.now())))"
        }
    }

    // MARK: - Internals

    private func ensureTimer() {
        guard tickTimer == nil else { return }
        tickTimer = driver.every(settings.tickInterval) { [weak self] in
            self?.tick()
        }
    }

    private func clearTimer() {
        tickTimer?.stop()
        tickTimer = nil
    }

    private func tick() {
        if state.phase == .idle || state.phase == .paused { return }
        let step = Pomodoro.tick(state, now: driver.now())
        if !step.transitions.isEmpty {
            applyStep(step)
        } else {
            notifyUpdate()
        }
    }

    private func applyStep(_ step: PomodoroStep) {
        state = step.state
        for t in step.transitions { handle(t) }
        notifyUpdate()
    }

    private func notifyUpdate() {
        onUpdate?()
    }

    private func handle(_ t: PomodoroTransition) {
        log("transition=\(t)")
        switch t {
        case .started:
            driver.notify("🍅 开始工作 " + formatRemaining(settings.phases.workSeconds))
        case .phaseDone(let phase, _, _):
            if phase == .work {
                // The state machine has entered rest, but the break must not
                // count down until the user chooses an action.
                state = Pomodoro.awaitBreakChoice(state).state
                attemptLock()
            } else if phase == .rest || phase == .longRest {
                handleRestEnded(completedPhase: phase)
            }
        case .phaseSkipped(let phase, let newPhase):
            driver.notify("⏭  跳过 \(formatPhase(phase)) → \(formatPhase(newPhase))")
            pendingLockAttempts = nil
        case .paused:
            driver.notify("⏸  番茄钟已暂停")
        case .resumed:
            driver.notify("▶️ 番茄钟已恢复")
        case .cancelled:
            driver.notify("⏹  番茄钟已取消")
        }
    }

    /// Try to put the screen off; if the user is busy, schedule a retry.
    /// `busyMaxRetries` counts *additional* attempts after the first one.
    private func attemptLock() {
        guard state.phase == .paused,
              state.pausedPhase == .rest || state.pausedPhase == .longRest else {
            pendingLockAttempts = nil
            log("attemptLock -> ignored (no pending break choice)")
            return
        }
        let signals = driver.collectBusySignals()
        let verdict = BusyDetect.evaluate(signals: signals, keywords: settings.busyKeywords)
        log("attemptLock busy=\(verdict.busy) reasons=\(verdict.reasons)")
        if verdict.busy {
            let attempts = (pendingLockAttempts ?? 0) + 1
            pendingLockAttempts = attempts
            let canRetry = attempts <= settings.busyMaxRetries
            let suffix = canRetry
                ? "将在 \(Int(settings.busyGraceSeconds)) 秒后再试。"
                : "已达重试上限。"
            driver.notify("🍅 工作完成,但你正忙(\(verdict.reasons.joined(separator: "; "))). \(suffix)")
            if canRetry {
                _ = driver.after(settings.busyGraceSeconds) { [weak self] in
                    self?.attemptLock()
                }
            } else {
                pendingLockAttempts = nil
                driver.notify("🍅 忙碌检测达到重试上限，请选择如何继续。")
                presentWorkCompletePrompt()
            }
            return
        }
        pendingLockAttempts = nil
        presentWorkCompletePrompt()
    }

    private func presentWorkCompletePrompt() {
        log("attemptLock -> promptBreakBeforeLock(warning=\(settings.lockWarningSeconds)s discipline=\(settings.breakDiscipline.rawValue))")
        let restDuration = restDurationForCurrentPhase()
        if settings.lockWarningSeconds <= 0 {
            handleWorkCompleteDecision(.takeBreak)
            return
        }
        driver.promptBreakBeforeLock(
            restDuration: restDuration,
            warningSeconds: settings.lockWarningSeconds,
            discipline: settings.breakDiscipline,
            snoozeSeconds: settings.breakSnoozeSeconds
        ) { [weak self] decision in
            self?.handleWorkCompleteDecision(decision)
        }
    }

    private func restDurationForCurrentPhase() -> TimeInterval {
        let activePhase = state.phase == .paused ? state.pausedPhase : state.phase
        switch activePhase {
        case .rest:     return state.config.restSeconds
        case .longRest: return state.config.longRestSeconds
        default:        return state.config.restSeconds
        }
    }

    private func handleWorkCompleteDecision(_ decision: WorkCompleteDecision) {
        switch decision {
        case .takeBreak:
            applyStep(Pomodoro.beginPendingBreak(state, now: driver.now()))
            ensureTimer()
            if settings.breakDiscipline == .strict {
                log("finishLock -> putScreenOff(\(settings.lockMode.rawValue))")
                _ = driver.putScreenOff(settings.lockMode)
                driver.notify("🍅 工作完成，已息屏并开始休息。")
            } else {
                log("finishLock -> takeBreak(\(settings.breakDiscipline.rawValue))")
                driver.notify("🍅 工作完成，开始休息。")
            }
        case .snooze:
            log("finishLock -> snooze(\(settings.breakSnoozeSeconds)s)")
            applyStep(Pomodoro.snoozeBreak(state, now: driver.now(), seconds: settings.breakSnoozeSeconds))
            ensureTimer()
            driver.notify("🍅 已推迟休息 \(formatDuration(settings.breakSnoozeSeconds))。")
        case .skip:
            log("finishLock -> skipped")
            applyStep(Pomodoro.skipPendingBreak(state, now: driver.now()))
            ensureTimer()
            driver.notify("🍅 已跳过本次休息，开始下一工作周期。")
        }
    }

    private func handleRestEnded(completedPhase: PomodoroPhase) {
        pendingLockAttempts = nil
        if settings.lockWarningSeconds <= 0 {
            driver.notify("☕ 休息结束 — 开始工作")
            return
        }
        // Pause the newly-started work phase while the user decides.
        if state.phase == .work {
            applyStep(Pomodoro.pause(state, now: driver.now()))
        }
        driver.promptRestEnded(
            workDuration: settings.phases.workSeconds,
            warningSeconds: settings.lockWarningSeconds
        ) { [weak self] startWork in
            guard let self else { return }
            if startWork {
                self.startWorkAfterRest()
            } else {
                self.applyStep(Pomodoro.continueRest(
                    self.state, restPhase: completedPhase, now: self.driver.now()))
                self.ensureTimer()
                let label = completedPhase == .longRest ? "长休息" : "休息"
                self.driver.notify("☕ 继续\(label)")
            }
        }
    }

    private func startWorkAfterRest() {
        if state.phase == .paused, state.pausedPhase == .work {
            applyStep(Pomodoro.resume(state, now: driver.now()))
            ensureTimer()
        }
        driver.notify("🍅 开始工作 " + formatRemaining(settings.phases.workSeconds))
    }

    /// Append a diagnostic line to /tmp/freewindow_pomodoro.log. Best-effort.
    private func log(_ msg: String) {
        let line = "[PomodoroController] " + msg + "\n"
        let path = "/tmp/freewindow_pomodoro.log"
        if let data = line.data(using: .utf8) {
            if let fh = FileHandle(forWritingAtPath: path) {
                fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
            } else {
                FileManager.default.createFile(atPath: path, contents: data)
            }
        }
    }

    // MARK: - Formatting helpers

    private func formatPhase(_ p: PomodoroPhase) -> String {
        switch p {
        case .work:     return "🍅 工作"
        case .rest:     return "☕ 休息"
        case .longRest: return "🛋  长休息"
        case .paused:   return "已暂停"
        case .idle:     return "未启动"
        }
    }

    private func phaseEmoji(_ p: PomodoroPhase) -> String {
        switch p {
        case .work:     return "🍅"
        case .rest:     return "☕"
        case .longRest: return "🛋"
        default:        return "🍅"
        }
    }

    private func formatRemaining(_ secs: TimeInterval) -> String {
        let s = max(0, Int((secs + 0.5).rounded(.down)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func formatDuration(_ secs: TimeInterval) -> String {
        let mins = max(1, Int((secs / 60).rounded()))
        return "\(mins) 分钟"
    }
}
