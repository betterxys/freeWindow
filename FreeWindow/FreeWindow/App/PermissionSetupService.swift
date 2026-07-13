// PermissionSetupService.swift — First-run permission guidance for FreeWindow + Ice.

import AppKit
import ApplicationServices

final class PermissionSetupService {
    static let shared = PermissionSetupService()

    private var pollTimer: Timer?
    private var lastHotkeyWarning: Date?

    func start() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.check()
        }
    }

    /// Called when a window-management hotkey fires but AX is not trusted.
    func notifyHotkeyBlocked() {
        let now = Date()
        if let last = lastHotkeyWarning, now.timeIntervalSince(last) < 60 { return }
        lastHotkeyWarning = now

        if BinarySignatureTracker.binaryChangedSinceLastTrust {
            ToastService.shared.show("FreeWindow 已更新：请在辅助功能里把 FreeWindow 开关关再开一次")
        } else {
            ToastService.shared.show("窗口快捷键需要辅助功能：系统设置 → 辅助功能 → 打开 FreeWindow")
        }
    }

    /// User-initiated: open settings from the menu bar.
    func openSettingsFromMenu() {
        openAccessibilitySettings()
        ToastService.shared.show("在列表中找到 FreeWindow 并打开开关")
    }

    private func check() {
        if AXIsProcessTrusted() {
            BinarySignatureTracker.markTrusted()
            restartIceIfNeeded()
            return
        }
        requestSystemPromptOnceIfNeeded()
        startPolling()
    }

    /// Show the macOS system prompt once (adds FreeWindow to the Accessibility list).
    /// Avoids custom modal alerts that kept reappearing when TCC was stale.
    private func requestSystemPromptOnceIfNeeded() {
        let key = "freewindow.didRequestAXSystemPrompt"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if AXIsProcessTrusted() {
                self.pollTimer?.invalidate()
                self.pollTimer = nil
                BinarySignatureTracker.markTrusted()
                self.restartIceIfNeeded()
                ToastService.shared.show("✅ 辅助功能已就绪")
            }
        }
    }

    private func restartIceIfNeeded() {
        let iceURL = URL(fileURLWithPath: "/Applications/Ice.app")
        guard FileManager.default.fileExists(atPath: iceURL.path) else { return }
        let running = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.jordanbaird.Ice"
        }
        guard !running else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: iceURL, configuration: config)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
