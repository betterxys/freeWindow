import FreeWindowCore
// HotkeyService.swift — Global hotkey registration via Carbon RegisterEventHotKey.
// This is the same API used by Rectangle, Magnet, and other production window managers.
// It is more reliable than CGEventTap: properly suppresses events and doesn't break
// when the app binary is replaced.

import AppKit
import Carbon

/// Maps key names to Carbon virtual key codes.
enum KeyCode {
    static let mapping: [String: UInt32] = [
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

    static func code(for key: String) -> UInt32? {
        mapping[key.lowercased()]
    }
}

/// Convert HotkeyModifier set to Carbon modifier flags.
extension Set where Element == HotkeyModifier {
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.ctrl)  { flags |= UInt32(controlKey) }
        if contains(.alt)   { flags |= UInt32(optionKey) }
        if contains(.cmd)   { flags |= UInt32(cmdKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}

/// Global hotkey manager using Carbon RegisterEventHotKey.
final class HotkeyService {
    static let shared = HotkeyService()

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var handlers: [UInt32: () -> Void] = [:]  // hotKeyID → handler
    private var nextId: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private(set) var isRunning: Bool = false
    private(set) var lastError: String?
    var registeredCount: Int { handlers.count }

    /// Register a hotkey handler.
    func register(modifiers: Set<HotkeyModifier>, key: String, handler: @escaping () -> Void) {
        guard let keyCode = KeyCode.code(for: key) else {
            let msg = "[HotkeyService] ⚠️ Unknown key: '\(key)'\n"
            appendLog(msg)
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4657_494E), // "FWIN"
                                      id: nextId)
        let carbonMods = modifiers.carbonFlags

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, carbonMods, hotKeyID,
                                          GetApplicationEventTarget(), 0, &hotKeyRef)

        if status == noErr {
            handlers[nextId] = handler
            hotKeyRefs.append(hotKeyRef)
            let msg = "[HotkeyService] ✅ Registered #\(nextId): key=\(key)(code=\(keyCode)) mods=\(carbonMods)\n"
            appendLog(msg)
            nextId += 1
        } else {
            let msg = "[HotkeyService] ❌ Failed: key=\(key) status=\(status)\n"
            appendLog(msg)
        }
    }

    private func appendLog(_ msg: String) {
        let logFile = "/tmp/freewindow_hotkey.log"
        if let data = msg.data(using: .utf8) {
            if let fh = FileHandle(forWritingAtPath: logFile) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            } else {
                FileManager.default.createFile(atPath: logFile, contents: data)
            }
        }
    }

    /// Remove all registered hotkeys.
    func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
        nextId = 1
    }

    /// Start listening (install Carbon event handler).
    func start() {
        guard !isRunning else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status == noErr {
            isRunning = true
            lastError = nil
            print("[HotkeyService] ✅ Carbon hotkey handler installed. \(handlers.count) hotkeys registered.")
        } else {
            lastError = "InstallEventHandler failed: \(status)"
            print("[HotkeyService] ❌ \(lastError!)")
        }
    }

    /// Stop listening.
    func stop() {
        unregisterAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        isRunning = false
    }

    /// Called by the Carbon event handler when a hotkey fires.
    fileprivate func handleHotKey(id: UInt32) {
        if let handler = handlers[id] {
            DispatchQueue.main.async { handler() }
        }
    }

    // MARK: - Diagnostics

    func dumpRegisteredHotkeys() {
        print("[HotkeyService] === \(handlers.count) hotkeys registered (Carbon) ===")
    }
}

/// Carbon event handler callback (C function pointer).
private func hotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event,
                                    EventParamName(kEventParamDirectObject),
                                    EventParamType(typeEventHotKeyID),
                                    nil,
                                    MemoryLayout<EventHotKeyID>.size,
                                    nil,
                                    &hotKeyID)

    if status == noErr {
        let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
        service.handleHotKey(id: hotKeyID.id)
    }

    return noErr
}
