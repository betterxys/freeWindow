// SystemPomodoroDriver.swift — Production wiring for `PomodoroDriver`.
// Maps the abstract driver protocol to real Foundation Timers,
// BusySignalCollector, ScreenLockService and ToastService.

import Foundation
import FreeWindowCore

/// Wraps a Foundation Timer in the `PomodoroTimerHandle` shape the
/// controller expects.
final class FoundationTimerHandle: PomodoroTimerHandle {
    private var timer: Timer?
    init(timer: Timer) { self.timer = timer }
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

final class SystemPomodoroDriver: PomodoroDriver {
    private let collector: BusySignalCollector
    private let lockService: ScreenLockService
    private let toast: ToastService
    private let breakReminder: BreakReminderService

    init(
        collector: BusySignalCollector = .shared,
        lockService: ScreenLockService = .shared,
        toast: ToastService = .shared,
        breakReminder: BreakReminderService = .shared
    ) {
        self.collector = collector
        self.lockService = lockService
        self.toast = toast
        self.breakReminder = breakReminder
    }

    func now() -> TimeInterval {
        Date().timeIntervalSince1970
    }

    func every(_ interval: TimeInterval, _ fn: @escaping () -> Void) -> PomodoroTimerHandle {
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in fn() }
        return FoundationTimerHandle(timer: t)
    }

    func after(_ delay: TimeInterval, _ fn: @escaping () -> Void) -> PomodoroTimerHandle {
        let t = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in fn() }
        return FoundationTimerHandle(timer: t)
    }

    func collectBusySignals() -> BusySignals {
        collector.collect()
    }

    func putScreenOff(_ mode: ScreenLockMode) -> Bool {
        lockService.apply(mode)
    }

    func notify(_ message: String) {
        toast.show(message)
    }

    func promptBreakBeforeLock(
        restDuration: TimeInterval,
        warningSeconds: TimeInterval,
        discipline: BreakDiscipline,
        snoozeSeconds: TimeInterval,
        completion: @escaping (WorkCompleteDecision) -> Void
    ) {
        breakReminder.showWorkComplete(
            restDuration: restDuration,
            warningSeconds: warningSeconds,
            discipline: discipline,
            snoozeSeconds: snoozeSeconds,
            completion: completion
        )
    }

    func promptRestEnded(
        workDuration: TimeInterval,
        warningSeconds: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) {
        breakReminder.showRestEnded(
            workDuration: workDuration,
            warningSeconds: warningSeconds,
            completion: completion
        )
    }

    func dismissBreakReminder() {
        breakReminder.dismiss()
    }
}
