import AppKit

/// Offers to move HushBar into `/Applications` when it's launched from elsewhere
/// (the DMG, `~/Downloads`, the Desktop, …) — the same courtesy Postman and many
/// other Mac apps provide. Minimal, self-contained, no third-party dependency.
///
/// Call `promptToMoveIfNeeded()` once at launch, before anything else spins up:
/// if the user accepts, the app copies itself, relaunches from `/Applications`,
/// and terminates the original — so no controllers should be running yet.
enum MoveToApplications {

    private static let declinedKey = "moveToApplicationsDeclined"

    static func promptToMoveIfNeeded() {
        #if DEBUG
        // Never nag during development.
        return
        #else
        guard shouldPrompt() else { return }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Move HushBar to Applications?"
        alert.informativeText = "HushBar works best from your Applications folder. "
            + "Would you like to move it there now?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")

        if alert.runModal() == .alertFirstButtonReturn {
            moveToApplications()
        } else {
            UserDefaults.standard.set(true, forKey: declinedKey)
            hushLog("move-to-Applications declined by user")
        }
        #endif
    }

    // MARK: - Conditions

    private static func shouldPrompt() -> Bool {
        if UserDefaults.standard.bool(forKey: declinedKey) { return false }

        let path = Bundle.main.bundlePath

        // Already installed.
        if path.hasPrefix("/Applications/") { return false }
        let userApps = (NSHomeDirectory() as NSString).appendingPathComponent("Applications") + "/"
        if path.hasPrefix(userApps) { return false }

        // Running from an Xcode build location — don't prompt while developing.
        if path.contains("/DerivedData/") || path.contains("/Build/Products/") { return false }

        return true
    }

    // MARK: - The move

    private static func moveToApplications() {
        let fm = FileManager.default
        let srcURL = Bundle.main.bundleURL
        let appName = srcURL.lastPathComponent                 // "hushBar.app"
        let destURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(appName)

        // A copy already lives in /Applications — just launch that one.
        if fm.fileExists(atPath: destURL.path) {
            hushLog("HushBar already in /Applications; launching installed copy")
            relaunch(at: destURL)
            return
        }

        do {
            try fm.copyItem(at: srcURL, to: destURL)
            stripQuarantine(destURL)
            hushLog("moved HushBar to /Applications")
            relaunch(at: destURL)
        } catch {
            hushLog("move-to-Applications failed: \(error.localizedDescription)")
            showManualFallback(srcURL: srcURL)
        }
    }

    private static func stripQuarantine(_ url: URL) {
        let task = Process()
        task.launchPath = "/usr/bin/xattr"
        task.arguments = ["-dr", "com.apple.quarantine", url.path]
        try? task.run()
        task.waitUntilExit()
    }

    /// Launch the copy at `url`, then terminate this instance.
    private static func relaunch(at url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private static func showManualFallback(srcURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Couldn't move HushBar automatically"
        alert.informativeText = "Please drag HushBar into your Applications folder manually."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reveal in Finder")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([srcURL])
        }
    }
}
