// BinarySignatureTracker.swift — Detect when a rebuilt binary invalidates TCC trust.

import Foundation

enum BinarySignatureTracker {
    private static let trustedFingerprintKey = "freewindow.lastTrustedExecutableFingerprint"

    /// Fingerprint of the running executable on disk (changes on every ad-hoc rebuild).
    static func currentFingerprint() -> String? {
        guard let url = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64,
              let modified = attrs[.modificationDate] as? Date
        else { return nil }
        return "\(size)-\(Int(modified.timeIntervalSince1970))"
    }

    static var lastTrustedFingerprint: String? {
        UserDefaults.standard.string(forKey: trustedFingerprintKey)
    }

    static var binaryChangedSinceLastTrust: Bool {
        guard let current = currentFingerprint(),
              let last = lastTrustedFingerprint
        else { return false }
        return current != last
    }

    static func markTrusted() {
        guard let current = currentFingerprint() else { return }
        UserDefaults.standard.set(current, forKey: trustedFingerprintKey)
    }
}
