// BundledAppInstaller.swift — Install and launch embedded companion apps.

import AppKit

enum BundledAppInstaller {
    private static let iceBundleID = "com.jordanbaird.Ice"
    private static let iceDestination = URL(fileURLWithPath: "/Applications/Ice.app")

    /// Ensure Ice is installed from the embedded copy and running.
    static func ensureIce() {
        DispatchQueue.main.async {
            installIceIfMissing()
            launchIceIfNeeded()
        }
    }

    /// Only copy embedded Ice when /Applications/Ice.app does not exist.
    /// Never overwrite an existing install — that would invalidate TCC permissions.
    private static func installIceIfMissing() {
        if FileManager.default.fileExists(atPath: iceDestination.path) {
            return
        }
        guard let source = embeddedIceURL() else {
            NSLog("[FreeWindow] Embedded Ice.app not found — menu bar management unavailable")
            return
        }
        do {
            try FileManager.default.copyItem(at: source, to: iceDestination)
            ToastService.shared.show("已自动安装 Ice（菜单栏管理）")
        } catch {
            NSLog("[FreeWindow] Failed to install Ice: %@", "\(error)")
            ToastService.shared.show("Ice 安装失败：\(error.localizedDescription)")
        }
    }

    private static func embeddedIceURL() -> URL? {
        if let url = Bundle.main.url(forResource: "Ice", withExtension: "app", subdirectory: "Embedded") {
            return url
        }
        let manual = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/Embedded/Ice.app")
        return FileManager.default.fileExists(atPath: manual.path) ? manual : nil
    }

    private static func launchIceIfNeeded() {
        guard FileManager.default.fileExists(atPath: iceDestination.path) else { return }
        let running = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == iceBundleID
        }
        guard !running else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: iceDestination, configuration: config) { _, error in
            if let error {
                NSLog("[FreeWindow] Failed to launch Ice: %@", "\(error)")
            }
        }
    }
}
