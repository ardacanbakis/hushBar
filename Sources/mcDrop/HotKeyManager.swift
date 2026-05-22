import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Toggles the system microphone mute. Default: ⇧⌘M.
    static let toggleMute = Self("toggleMute", default: .init(.m, modifiers: [.command, .shift]))
}

/// Registers the global toggle-mute shortcut. Backed by Carbon
/// `RegisterEventHotKey` under the hood (via the KeyboardShortcuts package),
/// so it needs no Accessibility permission and works inside the App Sandbox.
final class HotKeyManager {

    init(onToggle: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .toggleMute) {
            onToggle()
        }
    }
}
