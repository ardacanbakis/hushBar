import AppKit
import AVFoundation
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let mic = MicMuteController()
    private let settings = AppSettings.shared
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
        // Offer to move into /Applications when launched from the DMG or Downloads.
        // If the user accepts, the app relaunches from /Applications and this
        // instance terminates, so do this before any controllers spin up.
        MoveToApplications.promptToMoveIfNeeded()

        requestMicrophoneAccess()
        statusController = StatusItemController(mic: mic, settings: settings) { [weak self] in
            self?.showPreferences()
        }
        hotKeyManager = HotKeyManager { [weak self] in
            self?.mic.toggle()
        }
    }

    /// Microphone authorization is required for our CoreAudio device writes to
    /// affect the real input device system-wide; without it macOS virtualizes
    /// them. We never open a capture session, so no recording actually occurs.
    private func requestMicrophoneAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        hushLog("microphone authorization status=\(status.rawValue)")
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                hushLog("microphone access granted=\(granted ? 1 : 0)")
            }
        }
    }

    @objc private func showPreferences() {
        settings.preferencesOpenCount += 1
        if preferencesWindow == nil {
            let hosting = NSHostingController(rootView: PreferencesView(mic: mic, settings: settings))
            let window = NSWindow(contentViewController: hosting)
            window.title = "HushBar Preferences"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    ? NSColor(white: 0.18, alpha: 1)
                    : NSColor(white: 0.96, alpha: 1)
            }
            window.center()
            preferencesWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.makeKeyAndOrderFront(nil)
        preferencesWindow?.orderFrontRegardless()
    }
}
