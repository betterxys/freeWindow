// TestRunner.swift — Simple test runner that works without XCTest/Xcode.
// Run with: swift run FreeWindowTestRunner

import Foundation
import FreeWindowCore

// MARK: - Mini Test Framework

var totalTests = 0
var passedTests = 0
var failedTests: [(String, String)] = []

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: String = #file, line: Int = #line) {
    totalTests += 1
    if a == b {
        passedTests += 1
    } else {
        let info = msg.isEmpty ? "\(a) != \(b)" : "\(msg): \(a) != \(b)"
        failedTests.append(("\(file):\(line)", info))
    }
}

func assertNil<T>(_ value: T?, _ msg: String = "", file: String = #file, line: Int = #line) {
    totalTests += 1
    if value == nil {
        passedTests += 1
    } else {
        failedTests.append(("\(file):\(line)", "\(msg): expected nil, got \(value!)"))
    }
}

func assertNotNil<T>(_ value: T?, _ msg: String = "", file: String = #file, line: Int = #line) {
    totalTests += 1
    if value != nil {
        passedTests += 1
    } else {
        failedTests.append(("\(file):\(line)", "\(msg): expected non-nil"))
    }
}

func assertTrue(_ value: Bool, _ msg: String = "", file: String = #file, line: Int = #line) {
    totalTests += 1
    if value {
        passedTests += 1
    } else {
        failedTests.append(("\(file):\(line)", "\(msg): expected true"))
    }
}

func section(_ name: String) {
    print("  \(name)")
}

// MARK: - Geometry Tests

func testGeometry() {
    print("\n📐 Geometry Tests")
    let screen = WMRect(x: 0, y: 0, w: 1920, h: 1080)

    section("Half")
    assertEqual(Geometry.half(frame: screen, .left), WMRect(x: 0, y: 0, w: 960, h: 1080), "left half")
    assertEqual(Geometry.half(frame: screen, .right), WMRect(x: 960, y: 0, w: 960, h: 1080), "right half")
    assertEqual(Geometry.half(frame: screen, .top), WMRect(x: 0, y: 0, w: 1920, h: 540), "top half")
    assertEqual(Geometry.half(frame: screen, .bottom), WMRect(x: 0, y: 540, w: 1920, h: 540), "bottom half")

    section("Quadrants")
    assertEqual(Geometry.quadrant(frame: screen, .nw), WMRect(x: 0, y: 0, w: 960, h: 540), "NW")
    assertEqual(Geometry.quadrant(frame: screen, .ne), WMRect(x: 960, y: 0, w: 960, h: 540), "NE")
    assertEqual(Geometry.quadrant(frame: screen, .sw), WMRect(x: 0, y: 540, w: 960, h: 540), "SW")
    assertEqual(Geometry.quadrant(frame: screen, .se), WMRect(x: 960, y: 540, w: 960, h: 540), "SE")

    section("Thirds")
    assertEqual(Geometry.third(frame: screen, .left), WMRect(x: 0, y: 0, w: 640, h: 1080), "left third")
    assertEqual(Geometry.third(frame: screen, .center), WMRect(x: 640, y: 0, w: 640, h: 1080), "center third")
    assertEqual(Geometry.third(frame: screen, .right), WMRect(x: 1280, y: 0, w: 640, h: 1080), "right third")
    assertEqual(Geometry.twoThirds(frame: screen, .left), WMRect(x: 0, y: 0, w: 1280, h: 1080), "left 2/3")
    assertEqual(Geometry.twoThirds(frame: screen, .right), WMRect(x: 640, y: 0, w: 1280, h: 1080), "right 2/3")

    section("Grid")
    assertEqual(Geometry.gridCell(frame: screen, cols: 3, rows: 3, col: 1, row: 1), WMRect(x: 0, y: 0, w: 640, h: 360), "grid 1,1")
    assertEqual(Geometry.gridCell(frame: screen, cols: 3, rows: 3, col: 2, row: 2), WMRect(x: 640, y: 360, w: 640, h: 360), "grid 2,2")
    assertEqual(Geometry.gridCell(frame: screen, cols: 3, rows: 3, col: 3, row: 3), WMRect(x: 1280, y: 720, w: 640, h: 360), "grid 3,3")

    section("Maximize & Center")
    assertEqual(Geometry.maximize(frame: screen), screen, "maximize")
    assertEqual(Geometry.centered(frame: screen, rect: WMRect(x: 100, y: 100, w: 400, h: 300)),
                WMRect(x: 760, y: 390, w: 400, h: 300), "centered")

    section("Clamp")
    assertEqual(Geometry.clamp(rect: WMRect(x: 100, y: 100, w: 400, h: 300), frame: screen),
                WMRect(x: 100, y: 100, w: 400, h: 300), "already inside")
    assertEqual(Geometry.clamp(rect: WMRect(x: 1800, y: 100, w: 400, h: 300), frame: screen),
                WMRect(x: 1520, y: 100, w: 400, h: 300), "overflow right")
    assertEqual(Geometry.clamp(rect: WMRect(x: -100, y: 100, w: 400, h: 300), frame: screen),
                WMRect(x: 0, y: 100, w: 400, h: 300), "overflow left")
    assertEqual(Geometry.clamp(rect: WMRect(x: 0, y: 0, w: 3000, h: 2000), frame: screen),
                WMRect(x: 0, y: 0, w: 1920, h: 1080), "too large")

    section("Nudge")
    assertEqual(Geometry.nudge(rect: WMRect(x: 0, y: 0, w: 960, h: 540), frame: screen, direction: .right, cols: 12, rows: 8),
                WMRect(x: 160, y: 0, w: 960, h: 540), "nudge right")
    assertEqual(Geometry.nudge(rect: WMRect(x: 0, y: 0, w: 960, h: 540), frame: screen, direction: .left, cols: 12, rows: 8),
                WMRect(x: 0, y: 0, w: 960, h: 540), "nudge left (clamped)")
    assertEqual(Geometry.nudge(rect: WMRect(x: 0, y: 0, w: 960, h: 540), frame: screen, direction: .down, cols: 12, rows: 8),
                WMRect(x: 0, y: 135, w: 960, h: 540), "nudge down")

    section("Resize")
    assertEqual(Geometry.resizeWidth(rect: WMRect(x: 0, y: 0, w: 960, h: 540), frame: screen, deltaCols: 1, cols: 12),
                WMRect(x: 0, y: 0, w: 1120, h: 540), "wider")
    assertEqual(Geometry.resizeWidth(rect: WMRect(x: 0, y: 0, w: 960, h: 540), frame: screen, deltaCols: -1, cols: 12),
                WMRect(x: 0, y: 0, w: 800, h: 540), "narrower")
    assertEqual(Geometry.resizeHeight(rect: WMRect(x: 0, y: 0, w: 960, h: 540), frame: screen, deltaRows: 1, rows: 8),
                WMRect(x: 0, y: 0, w: 960, h: 675), "taller")

    section("Cross-screen move")
    let screen1 = WMRect(x: 0, y: 0, w: 1920, h: 1080)
    let screen2 = WMRect(x: 1920, y: 0, w: 2560, h: 1440)
    assertEqual(Geometry.moveToScreen(rect: WMRect(x: 0, y: 0, w: 960, h: 1080), from: screen1, to: screen2, mode: .ratios),
                WMRect(x: 1920, y: 0, w: 1280, h: 1440), "ratios mode")

    section("Screen detection")
    let screens = [
        ScreenInfo(id: 1, name: "Left", frame: WMRect(x: 0, y: 0, w: 1920, h: 1080)),
        ScreenInfo(id: 2, name: "Right", frame: WMRect(x: 1920, y: 0, w: 1920, h: 1080)),
    ]
    assertEqual(Geometry.screenForRect(screens: screens, rect: WMRect(x: 100, y: 100, w: 400, h: 300)), 0, "left screen")
    assertEqual(Geometry.screenForRect(screens: screens, rect: WMRect(x: 2000, y: 100, w: 400, h: 300)), 1, "right screen")
}

// MARK: - Screen Layout Tests

func testScreenLayout() {
    print("\n🖥️  Screen Layout Tests")

    section("Ordering by X")
    let screens1 = [
        ScreenInfo(id: 2, name: "Right", frame: WMRect(x: 1920, y: 0, w: 1920, h: 1080)),
        ScreenInfo(id: 1, name: "Left", frame: WMRect(x: 0, y: 0, w: 1920, h: 1080)),
    ]
    let resolver1 = ScreenResolver(screens: screens1)
    assertEqual(resolver1.ordered[0].name, "Left", "first is Left")
    assertEqual(resolver1.ordered[1].name, "Right", "second is Right")

    section("Three-screen ordering")
    let screens3 = [
        ScreenInfo(id: 3, name: "Right", frame: WMRect(x: 3840, y: 0, w: 1920, h: 1080)),
        ScreenInfo(id: 1, name: "Left", frame: WMRect(x: 0, y: 0, w: 1920, h: 1080)),
        ScreenInfo(id: 2, name: "Center", frame: WMRect(x: 1920, y: 0, w: 1920, h: 1080)),
    ]
    let resolver3 = ScreenResolver(screens: screens3)
    assertEqual(resolver3.ordered[0].name, "Left")
    assertEqual(resolver3.ordered[1].name, "Center")
    assertEqual(resolver3.ordered[2].name, "Right")

    section("Index lookup")
    assertEqual(resolver3.indexForId(1), 0)
    assertEqual(resolver3.indexForId(2), 1)
    assertEqual(resolver3.indexForId(3), 2)
    assertNil(resolver3.indexForId(99), "nonexistent id")
    assertEqual(resolver3.indexForName("Center"), 1)

    section("Cycling")
    assertEqual(resolver3.nextIndex(from: 0, step: 1), 1)
    assertEqual(resolver3.nextIndex(from: 2, step: 1), 0, "wrap forward")
    assertEqual(resolver3.nextIndex(from: 0, step: -1), 2, "wrap backward")
}

// MARK: - Actions Tests

func testActions() {
    print("\n🎯 Actions Tests")

    let screen1 = ScreenInfo(id: 1, name: "Left", frame: WMRect(x: 0, y: 0, w: 1920, h: 1080))
    let screen2 = ScreenInfo(id: 2, name: "Right", frame: WMRect(x: 1920, y: 0, w: 2560, h: 1440))
    let screens = [screen1, screen2]
    let resolver = ScreenResolver(screens: screens)

    func ctx(windowFrame: WMRect = WMRect(x: 100, y: 100, w: 800, h: 600), screenIndex: Int = 0) -> ActionContext {
        ActionContext(windowFrame: windowFrame, screenIndex: screenIndex, screens: resolver.ordered, resolver: resolver, grid: .default)
    }

    section("Halves")
    assertEqual(Actions.leftHalf(ctx()), WMRect(x: 0, y: 0, w: 960, h: 1080), "left half")
    assertEqual(Actions.rightHalf(ctx()), WMRect(x: 960, y: 0, w: 960, h: 1080), "right half")

    section("Maximize & Center")
    assertEqual(Actions.maximize(ctx()), WMRect(x: 0, y: 0, w: 1920, h: 1080), "maximize")
    assertEqual(Actions.center(ctx(windowFrame: WMRect(x: 0, y: 0, w: 400, h: 300))),
                WMRect(x: 760, y: 390, w: 400, h: 300), "center")

    section("3×3 Grid")
    assertEqual(Actions.grid3x3(ctx(), cell: 1), WMRect(x: 0, y: 0, w: 640, h: 360), "cell 1")
    assertEqual(Actions.grid3x3(ctx(), cell: 5), WMRect(x: 640, y: 360, w: 640, h: 360), "cell 5")
    assertEqual(Actions.grid3x3(ctx(), cell: 9), WMRect(x: 1280, y: 720, w: 640, h: 360), "cell 9")

    section("Cross-screen")
    let c = ctx(windowFrame: WMRect(x: 0, y: 0, w: 960, h: 1080))
    let r = Actions.sendToScreen(c, targetIndex: 1, mode: .ratios)
    assertEqual(r!, WMRect(x: 1920, y: 0, w: 1280, h: 1440), "send to screen 2")
    assertNil(Actions.sendToScreen(ctx(), targetIndex: 0), "same screen returns nil")
    assertNil(Actions.sendToScreen(ctx(), targetIndex: 5), "invalid screen returns nil")
    assertNotNil(Actions.sendToNextScreen(ctx(), step: 1), "next screen")
}

// MARK: - Hotkey Bindings Tests

func testHotkeyBindings() {
    print("\n⌨️  Hotkey Bindings Tests")

    section("Binding count")
    let bindings = HotkeyBindings.build()
    assertEqual(bindings.count, 37, "expected 37 bindings")

    section("No conflicts")
    let conflicts = HotkeyBindings.detectConflicts(bindings)
    assertEqual(conflicts.count, 0, "no conflicts in default bindings")

    section("Conflict detection")
    let conflicting = [
        HotkeyBinding(modifiers: [.ctrl, .alt, .cmd], key: "h", name: "left_half") { _ in nil },
        HotkeyBinding(modifiers: [.ctrl, .alt, .cmd], key: "h", name: "duplicate") { _ in nil },
    ]
    assertEqual(HotkeyBindings.detectConflicts(conflicting).count, 1, "detect one conflict")

    section("Unique names")
    let names = Set(bindings.map(\.name))
    assertEqual(names.count, bindings.count, "all names unique")
}

// MARK: - Hotkey Registration E2E Test

// Local copy of KeyCode mapping for testing (mirrors HotkeyService.KeyCode)
private let keyCodeMapping: [String: UInt16] = [
    "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
    "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
    "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11, "1": 0x12,
    "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19,
    "7": 0x1A, "8": 0x1C, "0": 0x1D, "]": 0x1E, "o": 0x1F, "u": 0x20,
    "[": 0x21, "i": 0x22, "p": 0x23, "return": 0x24, "l": 0x25,
    "j": 0x26, "k": 0x28, ";": 0x29, "n": 0x2D, "m": 0x2E,
    ",": 0x2B, ".": 0x2F, "/": 0x2C, "space": 0x31,
    "escape": 0x35, "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
]

/// Simulates the HotkeySignature logic for testing
private struct TestHotkeySignature: Hashable {
    let keyCode: UInt16
    let flagsRaw: UInt64

    init(keyCode: UInt16, modifiers: Set<HotkeyModifier>) {
        self.keyCode = keyCode
        var raw: UInt64 = 0
        if modifiers.contains(.ctrl)  { raw |= 0x00040000 } // CGEventFlags.maskControl
        if modifiers.contains(.alt)   { raw |= 0x00080000 } // CGEventFlags.maskAlternate
        if modifiers.contains(.cmd)   { raw |= 0x00100000 } // CGEventFlags.maskCommand
        if modifiers.contains(.shift) { raw |= 0x00020000 } // CGEventFlags.maskShift
        self.flagsRaw = raw
    }

    init(keyCode: UInt16, flagsRaw: UInt64) {
        self.keyCode = keyCode
        self.flagsRaw = flagsRaw
    }
}

func testHotkeyRegistration() {
    print("\n🔑 Hotkey Registration E2E Tests")

    section("KeyCode mapping completeness")
    // Verify all keys used in bindings have valid keycodes
    let bindings = HotkeyBindings.build()
    var unmapped: [String] = []
    for binding in bindings {
        if keyCodeMapping[binding.key.lowercased()] == nil {
            unmapped.append(binding.key)
        }
    }
    assertEqual(unmapped.count, 0, "all keys mapped; unmapped: \(unmapped)")

    section("Slash key '/' maps to keycode 0x2C (44)")
    assertEqual(keyCodeMapping["/"], 0x2C, "/ → 0x2C")

    section("Modifier flag conversion")
    let hyperSig = TestHotkeySignature(keyCode: 0x2C, modifiers: [.ctrl, .alt, .cmd])
    // Simulate what the event tap sees when ⌃⌥⌘ are held
    let ctrlFlag: UInt64  = 0x00040000
    let altFlag: UInt64   = 0x00080000
    let cmdFlag: UInt64   = 0x00100000
    let expectedFlags = ctrlFlag | altFlag | cmdFlag
    assertEqual(hyperSig.flagsRaw, expectedFlags, "hyper flags = ctrl|alt|cmd")

    section("HotkeySignature matching (simulated event)")
    // Registered: ⌃⌥⌘ + / (keycode 0x2C)
    let registered = TestHotkeySignature(keyCode: 0x2C, modifiers: [.ctrl, .alt, .cmd])
    // Incoming event: same flags, same keycode
    let incoming = TestHotkeySignature(keyCode: 0x2C, flagsRaw: expectedFlags)
    assertEqual(registered, incoming, "⌃⌥⌘/ registration matches event")

    section("Shift distinguishes hyper from hyper_shift")
    let hyperH = TestHotkeySignature(keyCode: 0x04, modifiers: [.ctrl, .alt, .cmd])
    let hyperShiftH = TestHotkeySignature(keyCode: 0x04, modifiers: [.ctrl, .alt, .cmd, .shift])
    assertTrue(hyperH != hyperShiftH, "hyper+H ≠ hyper_shift+H")

    section("No duplicate registrations in default bindings + extras")
    // Check that none of the extra keys (s, r, /, v, p) with hyper conflict with bindings
    let extraKeys: [(Set<HotkeyModifier>, String)] = [
        ([.ctrl, .alt, .cmd], "s"),  // save layout
        ([.ctrl, .alt, .cmd], "r"),  // restore layout
        ([.ctrl, .alt, .cmd], "/"),  // cheatsheet
        ([.ctrl, .alt, .cmd], "v"),  // clipboard
        ([.ctrl, .alt, .cmd], "p"),  // screenshot
        ([.ctrl, .alt, .cmd, .shift], "p"),  // remove pins
    ]
    var allSigs: [TestHotkeySignature] = bindings.map { b in
        TestHotkeySignature(keyCode: keyCodeMapping[b.key.lowercased()]!, modifiers: b.modifiers)
    }
    for (mods, key) in extraKeys {
        allSigs.append(TestHotkeySignature(keyCode: keyCodeMapping[key]!, modifiers: mods))
    }
    let uniqueSigs = Set(allSigs)
    assertEqual(allSigs.count, uniqueSigs.count, "no duplicate hotkey signatures")
}

// MARK: - Pomodoro state machine tests

func testPomodoro() {
    print("\n🍅 Pomodoro Tests")

    func cfg() -> PomodoroConfig {
        PomodoroConfig(
            workSeconds: 10,
            restSeconds: 3,
            longRestSeconds: 8,
            cyclesUntilLongRest: 3
        )
    }

    section("idle → start → work")
    var s = PomodoroState(config: cfg())
    assertEqual(s.phase, PomodoroPhase.idle, "initial idle")
    let r1 = Pomodoro.start(s, now: 100)
    assertEqual(r1.state.phase, PomodoroPhase.work, "after start")
    assertEqual(r1.state.startedAt!, 100, "startedAt set")
    assertEqual(r1.transitions.count, 1, "one transition")
    if case .started(let p) = r1.transitions[0] {
        assertEqual(p, PomodoroPhase.work, "started.work")
    } else {
        assertTrue(false, "transition[0] should be .started")
    }

    section("start no-op when already running")
    s = Pomodoro.start(PomodoroState(config: cfg()), now: 0).state
    let r2 = Pomodoro.start(s, now: 5)
    assertEqual(r2.transitions.count, 0, "no-op")
    assertEqual(r2.state.startedAt!, 0, "startedAt unchanged")

    section("tick before deadline")
    s = Pomodoro.start(PomodoroState(config: cfg()), now: 0).state
    let r3 = Pomodoro.tick(s, now: 5)
    assertEqual(r3.transitions.count, 0, "no transition")
    assertEqual(r3.state.phase, PomodoroPhase.work, "still work")

    section("tick at deadline -> rest")
    s = Pomodoro.start(PomodoroState(config: cfg()), now: 0).state
    let r4 = Pomodoro.tick(s, now: 10)
    assertEqual(r4.transitions.count, 1, "one transition")
    assertEqual(r4.state.phase, PomodoroPhase.rest, "phase=rest")
    assertEqual(r4.state.completedWorkCycles, 1, "1 cycle done")

    section("long_rest after Nth work cycle")
    s = PomodoroState(config: cfg()) // cyclesUntilLongRest = 3
    s = Pomodoro.start(s, now: 0).state
    s = Pomodoro.tick(s, now: 10).state    // cycle 1 done -> rest
    s = Pomodoro.tick(s, now: 13).state    // rest done -> work
    s = Pomodoro.tick(s, now: 23).state    // cycle 2 done -> rest
    s = Pomodoro.tick(s, now: 26).state    // rest done -> work
    s = Pomodoro.tick(s, now: 36).state    // cycle 3 done -> long_rest
    assertEqual(s.phase, PomodoroPhase.longRest, "long_rest after 3rd work cycle")
    assertEqual(s.completedWorkCycles, 3, "3 cycles done")

    section("pause / resume preserves elapsed")
    s = Pomodoro.start(PomodoroState(config: cfg()), now: 0).state
    let pp = Pomodoro.pause(s, now: 4)
    assertEqual(pp.state.phase, PomodoroPhase.paused, "paused phase")
    assertEqual(pp.state.elapsedAtPause, 4, "elapsed stored")
    // tick during pause = no change
    assertEqual(Pomodoro.tick(pp.state, now: 100).transitions.count, 0, "tick no-op while paused")

    let rp = Pomodoro.resume(pp.state, now: 20)
    assertEqual(rp.state.phase, PomodoroPhase.work, "resumed to work")
    // 6 more seconds needed (10 - 4)
    assertEqual(Pomodoro.tick(rp.state, now: 25).transitions.count, 0, "still in work")
    let done = Pomodoro.tick(rp.state, now: 26)
    assertEqual(done.state.phase, PomodoroPhase.rest, "finished after 26")

    section("continue_rest returns to rest instead of work")
    do {
        var s = Pomodoro.start(PomodoroState(config: cfg()), now: 0).state
        s = Pomodoro.tick(s, now: 10).state // work -> rest
        s = Pomodoro.tick(s, now: 13).state // rest -> work
        assertEqual(s.phase, PomodoroPhase.work)
        let back = Pomodoro.continueRest(s, restPhase: .rest, now: 20)
        assertEqual(back.state.phase, PomodoroPhase.rest)
        assertEqual(back.state.startedAt, 20)
    }

    section("skip → next phase")
    s = Pomodoro.start(PomodoroState(config: cfg()), now: 0).state
    let sk = Pomodoro.skip(s, now: 3)
    assertEqual(sk.state.phase, PomodoroPhase.rest, "skipped to rest")
    if case .phaseSkipped = sk.transitions[0] {} else {
        assertTrue(false, "transition[0] should be .phaseSkipped")
    }

    section("cancel resets to idle and zeroes cycles")
    s = Pomodoro.start(PomodoroState(config: cfg()), now: 0).state
    s = Pomodoro.tick(s, now: 10).state      // 1 cycle complete
    let c = Pomodoro.cancel(s)
    assertEqual(c.state.phase, PomodoroPhase.idle, "phase=idle")
    assertEqual(c.state.completedWorkCycles, 0, "cycles reset")
    assertNil(c.state.startedAt, "startedAt cleared")

    section("remaining/elapsed during work")
    s = Pomodoro.start(PomodoroState(config: cfg()), now: 100).state
    assertEqual(Pomodoro.remaining(s, now: 100), 10)
    assertEqual(Pomodoro.elapsed(s, now: 100), 0)
    assertEqual(Pomodoro.remaining(s, now: 103), 7)
    assertEqual(Pomodoro.elapsed(s, now: 103), 3)
    assertEqual(Pomodoro.remaining(s, now: 200), 0)

    section("phase boundary doesn't leak time on overshoot tick")
    // Tick at t=15 should put rest's startedAt at t=10 (the end of work),
    // not at t=15 — otherwise consecutive overshoots silently swallow time.
    s = Pomodoro.start(PomodoroState(config: cfg()), now: 0).state
    let st = Pomodoro.tick(s, now: 15).state
    assertEqual(st.phase, PomodoroPhase.rest)
    assertEqual(st.startedAt!, 10, "rest started at work boundary, not now")

    section("default config")
    let def = PomodoroState(config: PomodoroConfig())
    assertEqual(def.config.workSeconds,         25 * 60)
    assertEqual(def.config.restSeconds,          5 * 60)
    assertEqual(def.config.longRestSeconds,     15 * 60)
    assertEqual(def.config.cyclesUntilLongRest,        4)
}

// MARK: - Busy detection tests

func testBusyDetect() {
    print("\n👀 Busy-detect Tests")

    section("idle when no signals")
    let r0 = BusyDetect.evaluate(signals: BusySignals())
    assertEqual(r0.busy, false, "no signals = not busy")
    assertEqual(r0.reasons.count, 0)

    section("conferencing app match (case-insensitive)")
    let r1 = BusyDetect.evaluate(signals: BusySignals(processes: ["zoom.us", "Finder"]))
    assertEqual(r1.busy, true, "zoom.us makes us busy")
    assertTrue(r1.reasons[0].contains("zoom.us"), "reason mentions process")

    section("Chinese keywords")
    let r2 = BusyDetect.evaluate(signals: BusySignals(processes: ["腾讯会议"]))
    assertEqual(r2.busy, true, "腾讯会议 matches")

    section("dedup duplicate hits")
    let r3 = BusyDetect.evaluate(signals: BusySignals(processes: ["WeMeet", "WeMeet", "Slack"]))
    assertEqual(r3.busy, true)
    let occurrences = r3.reasons[0].components(separatedBy: "WeMeet").count - 1
    assertEqual(occurrences, 1, "WeMeet listed once even when duplicated")

    section("custom keywords override defaults")
    let r4 = BusyDetect.evaluate(signals: BusySignals(processes: ["Zoom"]),
                                  keywords: ["obs.app"])
    assertEqual(r4.busy, false, "Zoom not in custom list")

    section("does NOT match unrelated CLI tools that share a stem")
    // Regression test: a previous default keyword "lark" matched
    // `npm exec lark-mcp …` invocations on real machines.
    let r5 = BusyDetect.evaluate(signals: BusySignals(processes: [
        "npm exec @larksuiteoapi/lark-mcp mcp -a cli_a946…",
        "Finder",
    ]))
    assertEqual(r5.busy, false, "lark-mcp must not trigger busy")

    section("display mirroring flagged")
    let r6 = BusyDetect.evaluate(signals: BusySignals(displayMirrored: true))
    assertEqual(r6.busy, true)
    assertTrue(r6.reasons[0].contains("镜像"))

    section("capture and audio flagged independently")
    let r7 = BusyDetect.evaluate(signals: BusySignals(captureActive: true))
    assertEqual(r7.busy, true)
    let r8 = BusyDetect.evaluate(signals: BusySignals(audioInputInUse: true))
    assertEqual(r8.busy, true)

    section("aggregates multiple kinds")
    let r9 = BusyDetect.evaluate(signals: BusySignals(
        processes: ["zoom.us"], captureActive: true, audioInputInUse: true))
    assertEqual(r9.busy, true)
    assertEqual(r9.reasons.count, 3)
}

// MARK: - Pomodoro controller integration tests

/// Fake driver that exposes deterministic time and timer firing.
final class FakePomodoroDriver: PomodoroDriver {
    var clock: TimeInterval = 0
    var lockCalls: [ScreenLockMode] = []
    var notes: [String] = []
    var busySignals: BusySignals = BusySignals()
    var failLock = false
    var nextWorkCompleteDecision: WorkCompleteDecision = .takeBreak
    var dismissBreakReminderCalls = 0
    var autoCompleteWorkPrompt = true
    var workPromptCount = 0
    private var pendingWorkPrompt: ((WorkCompleteDecision) -> Void)?

    private final class FakeHandle: PomodoroTimerHandle {
        var stopped = false
        func stop() { stopped = true }
    }

    private struct PendingTimer {
        let kind: Kind
        let interval: TimeInterval
        var nextFire: TimeInterval
        let callback: () -> Void
        let handle: FakeHandle
        enum Kind { case every, after }
    }

    private var timers: [PendingTimer] = []

    func now() -> TimeInterval { clock }

    func every(_ interval: TimeInterval, _ fn: @escaping () -> Void) -> PomodoroTimerHandle {
        let h = FakeHandle()
        timers.append(PendingTimer(kind: .every, interval: interval,
                                    nextFire: clock + interval, callback: fn, handle: h))
        return h
    }

    func after(_ delay: TimeInterval, _ fn: @escaping () -> Void) -> PomodoroTimerHandle {
        let h = FakeHandle()
        timers.append(PendingTimer(kind: .after, interval: delay,
                                    nextFire: clock + delay, callback: fn, handle: h))
        return h
    }

    func collectBusySignals() -> BusySignals { busySignals }

    func putScreenOff(_ mode: ScreenLockMode) -> Bool {
        if failLock { return false }
        lockCalls.append(mode)
        return true
    }

    func notify(_ message: String) { notes.append(message) }

    func promptBreakBeforeLock(
        restDuration: TimeInterval,
        warningSeconds: TimeInterval,
        discipline: BreakDiscipline,
        snoozeSeconds: TimeInterval,
        completion: @escaping (WorkCompleteDecision) -> Void
    ) {
        workPromptCount += 1
        if autoCompleteWorkPrompt {
            completion(nextWorkCompleteDecision)
        } else {
            pendingWorkPrompt = completion
        }
    }

    func chooseWorkComplete(_ decision: WorkCompleteDecision) {
        let completion = pendingWorkPrompt
        pendingWorkPrompt = nil
        completion?(decision)
    }

    func promptRestEnded(
        workDuration: TimeInterval,
        warningSeconds: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) {
        completion(true)
    }

    func dismissBreakReminder() {
        dismissBreakReminderCalls += 1
    }

    /// Advance the fake clock by `dt`, firing any due timers in chronological
    /// order. Repeating timers reschedule themselves; one-shot timers expire.
    /// Newly-installed timers during a fire are picked up automatically.
    func advance(_ dt: TimeInterval) {
        let target = clock + dt
        while true {
            // Find the earliest pending fire that's ≤ target. Skip stopped.
            var bestIdx: Int? = nil
            for (i, t) in timers.enumerated() {
                if t.handle.stopped { continue }
                if t.nextFire > target { continue }
                if let b = bestIdx, timers[b].nextFire <= t.nextFire { continue }
                bestIdx = i
            }
            guard let i = bestIdx else { break }
            clock = timers[i].nextFire
            let cb = timers[i].callback
            if timers[i].kind == .every {
                timers[i].nextFire += timers[i].interval
            } else {
                timers[i].handle.stopped = true
            }
            cb()
        }
        clock = target
    }
}

func testPomodoroController() {
    print("\n🍅 Pomodoro Controller (integration)")

    func makeController() -> (PomodoroController, FakePomodoroDriver) {
        let driver = FakePomodoroDriver()
        let settings = PomodoroSettings(
            phases: PomodoroConfig(
                workSeconds: 6,
                restSeconds: 30,        // long enough that retries never
                longRestSeconds: 60,    // straddle a rest boundary in tests
                cyclesUntilLongRest: 2),
            lockMode: .displaysSleep,
            breakDiscipline: .strict,
            breakSnoozeSeconds: 5,
            busyKeywords: BusyDetect.defaultBusyKeywords,
            busyGraceSeconds: 5,
            busyMaxRetries: 2,
            tickInterval: 1
        )
        return (PomodoroController(settings: settings, driver: driver), driver)
    }

    section("start → work → boundary → lock")
    do {
        let (ctrl, drv) = makeController()
        ctrl.start()
        assertEqual(ctrl.state.phase, PomodoroPhase.work)
        drv.advance(5)
        assertEqual(ctrl.state.phase, PomodoroPhase.work, "still working at 5s")
        assertEqual(drv.lockCalls.count, 0, "no lock yet")
        drv.advance(1) // t=6: boundary
        assertEqual(ctrl.state.phase, PomodoroPhase.rest)
        assertEqual(drv.lockCalls.count, 1, "locked once")
        assertEqual(drv.lockCalls[0], ScreenLockMode.displaysSleep)
    }

    section("gentle mode starts rest without locking")
    do {
        let driver = FakePomodoroDriver()
        let settings = PomodoroSettings(
            phases: PomodoroConfig(workSeconds: 6, restSeconds: 30, longRestSeconds: 60, cyclesUntilLongRest: 2),
            lockMode: .displaysSleep,
            breakDiscipline: .gentle,
            busyKeywords: BusyDetect.defaultBusyKeywords,
            busyGraceSeconds: 5,
            busyMaxRetries: 2,
            tickInterval: 1
        )
        let ctrl = PomodoroController(settings: settings, driver: driver)
        ctrl.start()
        driver.advance(6)
        assertEqual(ctrl.state.phase, PomodoroPhase.rest)
        assertEqual(driver.lockCalls.count, 0, "gentle mode never sleeps display")
        assertTrue(driver.notes.last!.contains("开始休息"), "gentle mode starts rest")
    }

    section("snooze returns to short work extension")
    do {
        let driver = FakePomodoroDriver()
        driver.nextWorkCompleteDecision = .snooze
        let settings = PomodoroSettings(
            phases: PomodoroConfig(workSeconds: 6, restSeconds: 30, longRestSeconds: 60, cyclesUntilLongRest: 2),
            lockMode: .displaysSleep,
            breakDiscipline: .gentle,
            breakSnoozeSeconds: 2,
            busyKeywords: BusyDetect.defaultBusyKeywords,
            busyGraceSeconds: 5,
            busyMaxRetries: 2,
            tickInterval: 1
        )
        let ctrl = PomodoroController(settings: settings, driver: driver)
        ctrl.start()
        driver.advance(6)
        assertEqual(ctrl.state.phase, PomodoroPhase.work, "snooze returns to work")
        assertEqual(ctrl.status().remainingSeconds, 2, "snooze length is used")
        driver.nextWorkCompleteDecision = .takeBreak
        driver.advance(2)
        assertEqual(ctrl.state.phase, PomodoroPhase.rest, "rest starts after snooze")
        assertEqual(driver.lockCalls.count, 0)
    }

    section("pending choice freezes the full rest duration")
    do {
        let driver = FakePomodoroDriver()
        driver.autoCompleteWorkPrompt = false
        let settings = PomodoroSettings(
            phases: PomodoroConfig(workSeconds: 6, restSeconds: 30, longRestSeconds: 60, cyclesUntilLongRest: 2),
            breakDiscipline: .gentle,
            breakSnoozeSeconds: 5,
            tickInterval: 1
        )
        let ctrl = PomodoroController(settings: settings, driver: driver)
        ctrl.start()
        driver.advance(6)
        assertEqual(ctrl.state.phase, PomodoroPhase.paused, "wait for choice")
        assertEqual(ctrl.state.pausedPhase, PomodoroPhase.rest)
        assertEqual(ctrl.status().remainingSeconds, 30, "full rest remains")
        driver.advance(100)
        assertEqual(ctrl.state.phase, PomodoroPhase.paused, "waiting never auto-advances")
        assertEqual(ctrl.status().remainingSeconds, 30, "rest does not elapse behind dialog")

        driver.chooseWorkComplete(.takeBreak)
        assertEqual(ctrl.state.phase, PomodoroPhase.rest, "take break starts rest")
        assertEqual(ctrl.status().remainingSeconds, 30, "rest starts from full duration")
    }

    section("snooze works then asks again")
    do {
        let driver = FakePomodoroDriver()
        driver.autoCompleteWorkPrompt = false
        let settings = PomodoroSettings(
            phases: PomodoroConfig(workSeconds: 6, restSeconds: 30, longRestSeconds: 60, cyclesUntilLongRest: 2),
            breakDiscipline: .gentle,
            breakSnoozeSeconds: 5,
            tickInterval: 1
        )
        let ctrl = PomodoroController(settings: settings, driver: driver)
        ctrl.start()
        driver.advance(6)
        driver.chooseWorkComplete(.snooze)
        assertEqual(ctrl.state.phase, PomodoroPhase.work)
        assertEqual(ctrl.status().remainingSeconds, 5, "five-second test snooze")
        driver.advance(5)
        assertEqual(ctrl.state.phase, PomodoroPhase.paused, "prompt waits again after snooze")
        assertEqual(ctrl.state.pausedPhase, PomodoroPhase.rest)
        assertEqual(driver.workPromptCount, 2, "work-complete prompt shown again")
    }

    section("skip break begins the next full work period")
    do {
        let driver = FakePomodoroDriver()
        driver.autoCompleteWorkPrompt = false
        let settings = PomodoroSettings(
            phases: PomodoroConfig(workSeconds: 6, restSeconds: 30, longRestSeconds: 60, cyclesUntilLongRest: 2),
            breakDiscipline: .gentle,
            tickInterval: 1
        )
        let ctrl = PomodoroController(settings: settings, driver: driver)
        ctrl.start()
        driver.advance(6)
        assertEqual(ctrl.state.completedWorkCycles, 1)
        driver.chooseWorkComplete(.skip)
        assertEqual(ctrl.state.phase, PomodoroPhase.work, "break skipped")
        assertEqual(ctrl.status().remainingSeconds, 6, "next work gets full duration")
        assertEqual(ctrl.state.completedWorkCycles, 1, "completed cycle retained")
        assertTrue(driver.notes.last!.contains("下一工作周期"))
    }

    section("busy at boundary → defer → lock when free")
    do {
        let (ctrl, drv) = makeController()
        drv.busySignals = BusySignals(processes: ["zoom.us"])
        ctrl.start()
        drv.advance(6) // boundary while busy
        assertEqual(ctrl.state.phase, PomodoroPhase.paused, "break waits while busy")
        assertEqual(ctrl.state.pausedPhase, PomodoroPhase.rest)
        assertEqual(drv.lockCalls.count, 0, "lock suppressed because zoom")

        // Still busy on first retry
        drv.advance(5) // t=11, retry 1 fires (still busy)
        assertEqual(drv.lockCalls.count, 0, "still suppressed")

        // User leaves the meeting
        drv.busySignals = BusySignals()
        drv.advance(5) // t=16, retry 2 — now free
        assertEqual(drv.lockCalls.count, 1, "now locked")
    }

    section("gives up after busy_max_retries")
    do {
        let (ctrl, drv) = makeController()
        drv.autoCompleteWorkPrompt = false
        drv.busySignals = BusySignals(processes: ["wemeet"])
        ctrl.start()
        drv.advance(6) // attempt 1 (busy)
        drv.advance(5) // attempt 2 (busy)
        drv.advance(5) // attempt 3 (busy) — exceeds max → gives up
        assertEqual(drv.lockCalls.count, 0, "never locked while busy")
        assertEqual(drv.workPromptCount, 1, "asks user after retry limit")
        assertEqual(ctrl.state.phase, PomodoroPhase.paused, "still waiting for explicit choice")
    }

    section("pause / resume preserves remaining time")
    do {
        let (ctrl, drv) = makeController()
        ctrl.start()
        drv.advance(2)
        ctrl.pause()
        assertEqual(ctrl.state.phase, PomodoroPhase.paused)
        drv.advance(100) // huge sleep while paused
        assertEqual(ctrl.state.phase, PomodoroPhase.paused, "still paused")
        assertEqual(drv.lockCalls.count, 0, "no lock from sleep-while-paused")
        ctrl.resume()
        // 4 more seconds needed (6 - 2)
        drv.advance(3)
        assertEqual(ctrl.state.phase, PomodoroPhase.work, "still working")
        drv.advance(1)
        assertEqual(ctrl.state.phase, PomodoroPhase.rest, "rest after total 6s of work")
        assertEqual(drv.lockCalls.count, 1)
    }

    section("skip does NOT lock (manual action)")
    do {
        let (ctrl, drv) = makeController()
        ctrl.start()
        drv.advance(1)
        ctrl.skip()
        assertEqual(ctrl.state.phase, PomodoroPhase.rest)
        assertEqual(drv.lockCalls.count, 0, "skip never auto-locks")
    }

    section("cancel returns to idle and stops timer")
    do {
        let (ctrl, drv) = makeController()
        ctrl.start()
        drv.advance(2)
        ctrl.cancel()
        assertEqual(ctrl.state.phase, PomodoroPhase.idle)
        drv.advance(100)
        assertEqual(ctrl.state.phase, PomodoroPhase.idle, "stays idle")
        assertEqual(drv.lockCalls.count, 0)
    }

    section("user commands clear a stuck break overlay")
    do {
        let (ctrl, drv) = makeController()
        // start / pause / resume / skip / cancel each dismiss the reminder,
        // so a stuck overnight overlay clears on any interaction.
        ctrl.start()                       // 1
        drv.advance(2)
        ctrl.pause()                       // 2
        ctrl.resume()                      // 3
        ctrl.skip()                        // 4
        ctrl.cancel()                      // 5
        assertEqual(drv.dismissBreakReminderCalls, 5, "every command dismisses overlay")
    }

    section("toggle: idle → work → paused → work")
    do {
        let (ctrl, _) = makeController()
        ctrl.toggle()
        assertEqual(ctrl.state.phase, PomodoroPhase.work)
        ctrl.toggle()
        assertEqual(ctrl.state.phase, PomodoroPhase.paused)
        ctrl.toggle()
        assertEqual(ctrl.state.phase, PomodoroPhase.work)
    }

    section("long_rest after Nth work cycle")
    do {
        let (ctrl, drv) = makeController()
        ctrl.start()
        drv.advance(6)  // cycle 1
        assertEqual(ctrl.state.phase, PomodoroPhase.rest)
        drv.advance(30) // rest done
        assertEqual(ctrl.state.phase, PomodoroPhase.work)
        drv.advance(6)  // cycle 2 — long_rest
        assertEqual(ctrl.state.phase, PomodoroPhase.longRest)
    }

    section("status: remaining + elapsed")
    do {
        let (ctrl, drv) = makeController()
        ctrl.start()
        drv.advance(2)
        let st = ctrl.status()
        assertEqual(st.phase, PomodoroPhase.work)
        assertEqual(st.remainingSeconds, 4)
        assertEqual(st.elapsedSeconds, 2)
    }

    section("menuBarLabel: compact timer text")
    do {
        let (ctrl, drv) = makeController()
        assertTrue(ctrl.menuBarLabel() == nil, "idle → nil")
        ctrl.start()
        assertEqual(ctrl.menuBarLabel(), "🍅 0:06")
        drv.advance(2)
        assertEqual(ctrl.menuBarLabel(), "🍅 0:04")
        ctrl.pause()
        assertEqual(ctrl.menuBarLabel(), "⏸ 0:04")
        ctrl.cancel()
        assertTrue(ctrl.menuBarLabel() == nil, "cancelled → nil")
    }
}

print("═══════════════════════════════════════════════")
print("  FreeWindow Test Suite")
print("═══════════════════════════════════════════════")

testGeometry()
testScreenLayout()
testActions()
testHotkeyBindings()
testHotkeyRegistration()
testPomodoro()
testBusyDetect()
testPomodoroController()

print("\n═══════════════════════════════════════════════")
if failedTests.isEmpty {
    print("  ✅ All \(totalTests) tests passed!")
} else {
    print("  ❌ \(failedTests.count) of \(totalTests) tests failed:")
    for (location, msg) in failedTests {
        print("    FAIL: \(msg)")
        print("          at \(location)")
    }
}
print("═══════════════════════════════════════════════\n")

exit(failedTests.isEmpty ? 0 : 1)
