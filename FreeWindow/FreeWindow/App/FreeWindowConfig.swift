// FreeWindowConfig.swift — Optional user-supplied configuration.
// Read from `~/.freewindow/config.json` at launch. All fields optional;
// missing values fall back to compiled-in defaults so the app works
// without any config file at all.
//
// Example:
//
//     {
//       "pomodoro": {
//         "work_minutes": 25,
//         "rest_minutes": 5,
//         "long_rest_minutes": 15,
//         "cycles_until_long_rest": 4,
//         "lock_action": "displays_sleep",
//         "break_discipline": "gentle",
//         "break_snooze_minutes": 5,
//         "busy_grace_seconds": 60,
//         "busy_max_retries": 3,
//         "busy_keywords": ["zoom.us", "wemeet", ...]
//       }
//     }

import Foundation
import FreeWindowCore

struct FreeWindowConfig {
    let pomodoro: PomodoroSettings

    static func load() -> FreeWindowConfig {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".freewindow/config.json")
        guard let data = try? Data(contentsOf: url) else {
            return FreeWindowConfig(pomodoro: PomodoroSettings())
        }
        guard let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            NSLog("[FreeWindowConfig] could not parse %@", url.path)
            return FreeWindowConfig(pomodoro: PomodoroSettings())
        }
        let pom = (raw["pomodoro"] as? [String: Any]) ?? [:]
        return FreeWindowConfig(pomodoro: parsePomodoro(pom))
    }

    private static func parsePomodoro(_ raw: [String: Any]) -> PomodoroSettings {
        var s = PomodoroSettings()

        func seconds(secKey: String, minKey: String, default defaultValue: TimeInterval) -> TimeInterval {
            if let v = raw[secKey] as? Double { return v }
            if let v = raw[secKey] as? Int    { return TimeInterval(v) }
            if let v = raw[minKey] as? Double { return v * 60 }
            if let v = raw[minKey] as? Int    { return TimeInterval(v) * 60 }
            return defaultValue
        }

        s.phases = PomodoroConfig(
            workSeconds:           seconds(secKey: "work_seconds",      minKey: "work_minutes",      default: s.phases.workSeconds),
            restSeconds:           seconds(secKey: "rest_seconds",      minKey: "rest_minutes",      default: s.phases.restSeconds),
            longRestSeconds:       seconds(secKey: "long_rest_seconds", minKey: "long_rest_minutes", default: s.phases.longRestSeconds),
            cyclesUntilLongRest:   (raw["cycles_until_long_rest"] as? Int) ?? s.phases.cyclesUntilLongRest
        )

        if let modeStr = raw["lock_action"] as? String,
           let mode = ScreenLockMode(rawValue: modeStr) {
            s.lockMode = mode
        }
        if let disciplineStr = raw["break_discipline"] as? String,
           let discipline = BreakDiscipline(rawValue: disciplineStr) {
            s.breakDiscipline = discipline
        }
        if let kws = raw["busy_keywords"] as? [String], !kws.isEmpty {
            s.busyKeywords = kws
        }
        if let v = raw["busy_grace_seconds"] as? Double { s.busyGraceSeconds = v }
        if let v = raw["busy_grace_seconds"] as? Int    { s.busyGraceSeconds = TimeInterval(v) }
        if let v = raw["busy_max_retries"]  as? Int     { s.busyMaxRetries = v }
        if let v = raw["tick_interval"]     as? Double  { s.tickInterval = v }
        if let v = raw["tick_interval"]     as? Int     { s.tickInterval = TimeInterval(v) }
        if let v = raw["lock_warning_seconds"] as? Double { s.lockWarningSeconds = v }
        if let v = raw["lock_warning_seconds"] as? Int    { s.lockWarningSeconds = TimeInterval(v) }
        if let v = raw["break_snooze_seconds"] as? Double { s.breakSnoozeSeconds = v }
        if let v = raw["break_snooze_seconds"] as? Int    { s.breakSnoozeSeconds = TimeInterval(v) }
        if let v = raw["break_snooze_minutes"] as? Double { s.breakSnoozeSeconds = v * 60 }
        if let v = raw["break_snooze_minutes"] as? Int    { s.breakSnoozeSeconds = TimeInterval(v) * 60 }

        return s
    }
}
