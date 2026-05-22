import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` (macOS 13+) for the
/// "open at login" behavior. Sandbox- and App-Store-safe.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("muteMe: failed to update launch-at-login: \(error)")
            }
        }
    }
}
