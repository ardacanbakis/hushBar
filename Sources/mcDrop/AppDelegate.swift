import AppKit
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let mic = MicMuteController()
    private var statusController: StatusItemController?
    private var hotKeyManager: HotKeyManager?
    private var preferencesWindow: NSWindow?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(mic: mic) { [weak self] in
            self?.showPreferences()
        }
        hotKeyManager = HotKeyManager { [weak self] in
            self?.mic.toggle()
        }
    }

    @objc private func showPreferences() {
        if preferencesWindow == nil {
            let hosting = NSHostingController(rootView: PreferencesView(mic: mic))
            let window = NSWindow(contentViewController: hosting)
            window.title = "mcDrop Preferences"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            preferencesWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }
}
