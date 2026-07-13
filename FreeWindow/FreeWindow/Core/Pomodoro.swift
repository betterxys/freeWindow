// Pomodoro.swift — Pure pomodoro state machine.
// Direct port of modules/pomodoro.lua. No timers, no clock, no AppKit.
// The controller layer is responsible for advancing the clock and applying
// side effects.

import Foundation

public struct PomodoroConfig: Equatable {
    public var workSeconds: TimeInterval
    public var restSeconds: TimeInterval
    public var longRestSeconds: TimeInterval
    public var cyclesUntilLongRest: Int

    public init(
        workSeconds: TimeInterval = 25 * 60,
        restSeconds: TimeInterval = 5 * 60,
        longRestSeconds: TimeInterval = 15 * 60,
        cyclesUntilLongRest: Int = 4
    ) {
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.longRestSeconds = longRestSeconds
        self.cyclesUntilLongRest = cyclesUntilLongRest
    }
}

public enum PomodoroPhase: String, Equatable {
    case idle, work, rest, longRest, paused
}

/// Snapshot of the state machine. All mutations return a new snapshot, so
/// callers can diff transitions and the machine itself stays trivially
/// testable.
public struct PomodoroState: Equatable {
    public var config: PomodoroConfig
    public var phase: PomodoroPhase
    public var startedAt: TimeInterval?       // when current phase started
    public var elapsedAtPause: TimeInterval   // elapsed seconds before pause
    public var pausedPhase: PomodoroPhase?    // phase active when paused
    public var completedWorkCycles: Int

    public init(config: PomodoroConfig) {
        self.config = config
        self.phase = .idle
        self.startedAt = nil
        self.elapsedAtPause = 0
        self.pausedPhase = nil
        self.completedWorkCycles = 0
    }
}

public enum PomodoroTransition: Equatable {
    case started(phase: PomodoroPhase)
    case phaseDone(phase: PomodoroPhase, newPhase: PomodoroPhase, completedWorkCycles: Int)
    case phaseSkipped(phase: PomodoroPhase, newPhase: PomodoroPhase)
    case paused
    case resumed(phase: PomodoroPhase)
    case cancelled
}

public struct PomodoroStep: Equatable {
    public let state: PomodoroState
    public let transitions: [PomodoroTransition]
}

public enum Pomodoro {

    /// Total seconds budgeted for the given phase. Returns nil for idle/paused.
    public static func totalSeconds(_ phase: PomodoroPhase, config: PomodoroConfig) -> TimeInterval? {
        switch phase {
        case .work:     return config.workSeconds
        case .rest:     return config.restSeconds
        case .longRest: return config.longRestSeconds
        default:        return nil
        }
    }

    /// Seconds remaining in the current phase. 0 for idle.
    public static func remaining(_ state: PomodoroState, now: TimeInterval) -> TimeInterval {
        switch state.phase {
        case .idle:
            return 0
        case .paused:
            guard let p = state.pausedPhase, let total = totalSeconds(p, config: state.config) else { return 0 }
            return max(0, total - state.elapsedAtPause)
        default:
            guard let started = state.startedAt,
                  let total = totalSeconds(state.phase, config: state.config) else { return 0 }
            let elapsed = (now - started) + state.elapsedAtPause
            return max(0, total - elapsed)
        }
    }

    public static func elapsed(_ state: PomodoroState, now: TimeInterval) -> TimeInterval {
        switch state.phase {
        case .idle: return 0
        case .paused: return state.elapsedAtPause
        default:
            guard let started = state.startedAt else { return 0 }
            return (now - started) + state.elapsedAtPause
        }
    }

    /// Move from idle into the first work phase.
    public static func start(_ state: PomodoroState, now: TimeInterval) -> PomodoroStep {
        guard state.phase == .idle else {
            return PomodoroStep(state: state, transitions: [])
        }
        var s = state
        s.phase = .work
        s.startedAt = now
        s.elapsedAtPause = 0
        return PomodoroStep(state: s, transitions: [.started(phase: .work)])
    }

    public static func cancel(_ state: PomodoroState) -> PomodoroStep {
        guard state.phase != .idle else {
            return PomodoroStep(state: state, transitions: [])
        }
        var s = state
        s.phase = .idle
        s.startedAt = nil
        s.elapsedAtPause = 0
        s.pausedPhase = nil
        s.completedWorkCycles = 0
        return PomodoroStep(state: s, transitions: [.cancelled])
    }

    public static func pause(_ state: PomodoroState, now: TimeInterval) -> PomodoroStep {
        if state.phase == .idle || state.phase == .paused {
            return PomodoroStep(state: state, transitions: [])
        }
        var s = state
        let started = state.startedAt ?? now
        s.elapsedAtPause = (now - started) + state.elapsedAtPause
        s.pausedPhase = state.phase
        s.phase = .paused
        s.startedAt = nil
        return PomodoroStep(state: s, transitions: [.paused])
    }

    public static func resume(_ state: PomodoroState, now: TimeInterval) -> PomodoroStep {
        guard state.phase == .paused, let p = state.pausedPhase else {
            return PomodoroStep(state: state, transitions: [])
        }
        var s = state
        s.phase = p
        s.startedAt = now
        s.pausedPhase = nil
        return PomodoroStep(state: s, transitions: [.resumed(phase: p)])
    }

    /// Compute the phase that follows when `current` finishes. Long rest
    /// kicks in every Nth completed work cycle, where N = cyclesUntilLongRest.
    public static func nextPhase(after current: PomodoroPhase, state: PomodoroState) -> PomodoroPhase {
        switch current {
        case .work:
            let nextCompleted = state.completedWorkCycles + 1
            if state.config.cyclesUntilLongRest > 0
               && nextCompleted % state.config.cyclesUntilLongRest == 0 {
                return .longRest
            }
            return .rest
        case .rest, .longRest:
            return .work
        default:
            return .idle
        }
    }

    private static func completePhase(_ state: PomodoroState, at endTime: TimeInterval, kind: TransitionKind)
        -> (PomodoroState, PomodoroTransition)
    {
        let current = state.phase
        let next = nextPhase(after: current, state: state)
        var s = state
        if current == .work { s.completedWorkCycles += 1 }
        s.phase = next
        s.startedAt = endTime
        s.elapsedAtPause = 0
        s.pausedPhase = nil
        let transition: PomodoroTransition = kind == .skipped
            ? .phaseSkipped(phase: current, newPhase: next)
            : .phaseDone(phase: current, newPhase: next, completedWorkCycles: s.completedWorkCycles)
        return (s, transition)
    }

    private enum TransitionKind { case timer, skipped }

    /// Skip ahead: mark the current phase as finished. Manual.
    public static func skip(_ state: PomodoroState, now: TimeInterval) -> PomodoroStep {
        if state.phase == .idle || state.phase == .paused {
            return PomodoroStep(state: state, transitions: [])
        }
        let (s, t) = completePhase(state, at: now, kind: .skipped)
        return PomodoroStep(state: s, transitions: [t])
    }

    /// Advance the clock. If the timer for the current phase ran out, emit
    /// a `phaseDone` transition. Multiple expirations during one tick are
    /// collapsed: we never silently swallow a whole rest phase by ticking
    /// once at, say, t = 100 seconds when the work phase only lasts 25s.
    public static func tick(_ state: PomodoroState, now: TimeInterval) -> PomodoroStep {
        if state.phase == .idle || state.phase == .paused {
            return PomodoroStep(state: state, transitions: [])
        }
        guard let total = totalSeconds(state.phase, config: state.config),
              let started = state.startedAt else {
            return PomodoroStep(state: state, transitions: [])
        }
        let elapsed = (now - started) + state.elapsedAtPause
        guard elapsed >= total else {
            return PomodoroStep(state: state, transitions: [])
        }
        // The next phase starts at the moment the previous one *would have*
        // ended, not at `now`, so consecutive over-shoot ticks don't drift.
        let phaseEnd = started + (total - state.elapsedAtPause)
        let (s, t) = completePhase(state, at: phaseEnd, kind: .timer)
        return PomodoroStep(state: s, transitions: [t])
    }

    /// Return to a rest phase instead of starting work (user chose "继续休息").
    public static func continueRest(_ state: PomodoroState, restPhase: PomodoroPhase, now: TimeInterval)
        -> PomodoroStep
    {
        guard restPhase == .rest || restPhase == .longRest else {
            return PomodoroStep(state: state, transitions: [])
        }
        guard state.phase == .work || state.phase == .paused else {
            return PomodoroStep(state: state, transitions: [])
        }
        var s = state
        s.phase = restPhase
        s.startedAt = now
        s.elapsedAtPause = 0
        s.pausedPhase = nil
        return PomodoroStep(state: s, transitions: [])
    }

    /// Freeze a newly-entered rest phase at its full duration while the user
    /// decides whether to rest, snooze, or skip.
    public static func awaitBreakChoice(_ state: PomodoroState) -> PomodoroStep {
        guard state.phase == .rest || state.phase == .longRest else {
            return PomodoroStep(state: state, transitions: [])
        }
        var s = state
        s.pausedPhase = state.phase
        s.phase = .paused
        s.startedAt = nil
        s.elapsedAtPause = 0
        return PomodoroStep(state: s, transitions: [])
    }

    /// Start the full pending break from the moment the user confirms.
    public static func beginPendingBreak(_ state: PomodoroState, now: TimeInterval) -> PomodoroStep {
        guard state.phase == .paused,
              state.pausedPhase == .rest || state.pausedPhase == .longRest,
              let restPhase = state.pausedPhase else {
            return PomodoroStep(state: state, transitions: [])
        }
        var s = state
        s.phase = restPhase
        s.pausedPhase = nil
        s.startedAt = now
        s.elapsedAtPause = 0
        return PomodoroStep(state: s, transitions: [])
    }

    /// User postponed a break right after work completed. Return to work for a
    /// short one-off extension, then the next timer boundary will re-enter the
    /// same rest/long-rest phase because the completed cycle count is restored.
    public static func snoozeBreak(_ state: PomodoroState, now: TimeInterval, seconds: TimeInterval)
        -> PomodoroStep
    {
        let pendingRest = state.phase == .rest || state.phase == .longRest
            || (state.phase == .paused && (state.pausedPhase == .rest || state.pausedPhase == .longRest))
        guard pendingRest else {
            return PomodoroStep(state: state, transitions: [])
        }
        let extensionSeconds = max(1, min(seconds, state.config.workSeconds))
        var s = state
        s.phase = .work
        s.startedAt = now - (state.config.workSeconds - extensionSeconds)
        s.elapsedAtPause = 0
        s.pausedPhase = nil
        s.completedWorkCycles = max(0, state.completedWorkCycles - 1)
        return PomodoroStep(state: s, transitions: [])
    }

    /// Skip the pending break and explicitly begin the next full work period.
    public static func skipPendingBreak(_ state: PomodoroState, now: TimeInterval) -> PomodoroStep {
        let pendingRest = state.phase == .rest || state.phase == .longRest
            || (state.phase == .paused && (state.pausedPhase == .rest || state.pausedPhase == .longRest))
        guard pendingRest else {
            return PomodoroStep(state: state, transitions: [])
        }
        var s = state
        s.phase = .work
        s.pausedPhase = nil
        s.startedAt = now
        s.elapsedAtPause = 0
        return PomodoroStep(state: s, transitions: [])
    }
}
