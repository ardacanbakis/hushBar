import AppKit

/// Manages the menubar status item: renders the pill, routes left-click to a
/// mute toggle, and right-click (or control-click) to a context menu.
final class StatusItemController {

    private let statusItem: NSStatusItem
    private let mic: MicMuteController
    private let onOpenPreferences: () -> Void

    private lazy var contextMenu: NSMenu = makeMenu()

    init(mic: MicMuteController, onOpenPreferences: @escaping () -> Void) {
        self.mic = mic
        self.onOpenPreferences = onOpenPreferences
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        configureButton()
        render(muted: mic.isMuted)

        mic.onStateChange = { [weak self] muted in
            self?.render(muted: muted)
        }
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
    }

    private func render(muted: Bool) {
        guard let button = statusItem.button else { return }
        button.image = PillRenderer.image(muted: muted)
        button.toolTip = muted ? "Microphone muted — click to go live" : "Microphone live — click to mute"
        muteMenuItem?.title = muted ? "Unmute Microphone" : "Mute Microphone"
    }

    // MARK: - Click routing

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)

        if isRightClick {
            showMenu()
        } else {
            mic.toggle()
        }
    }

    private func showMenu() {
        statusItem.menu = contextMenu
        statusItem.button?.performClick(nil)
        // Detach so the next left-click reaches our action instead of the menu.
        statusItem.menu = nil
    }

    // MARK: - Menu

    private weak var muteMenuItem: NSMenuItem?

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let muteItem = NSMenuItem(
            title: mic.isMuted ? "Unmute Microphone" : "Mute Microphone",
            action: #selector(toggleFromMenu), keyEquivalent: "")
        muteItem.target = self
        menu.addItem(muteItem)
        muteMenuItem = muteItem

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let loginItem = NSMenuItem(
            title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit mcDrop", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func toggleFromMenu() {
        mic.toggle()
    }

    @objc private func openPreferences() {
        onOpenPreferences()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newValue = !LaunchAtLogin.isEnabled
        LaunchAtLogin.isEnabled = newValue
        sender.state = newValue ? .on : .off
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension StatusItemController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        for item in menu.items where item.action == #selector(toggleLaunchAtLogin(_:)) {
            item.state = LaunchAtLogin.isEnabled ? .on : .off
        }
    }
}
