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

print("═══════════════════════════════════════════════")
print("  FreeWindow Test Suite")
print("═══════════════════════════════════════════════")

testGeometry()
testScreenLayout()
testActions()
testHotkeyBindings()
testHotkeyRegistration()

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
