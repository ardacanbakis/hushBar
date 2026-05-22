# muteMe

A lightweight macOS menubar app that mutes/unmutes your microphone globally —
for every app at once — with one click or a global hotkey.

- **ON AIR** (red pill) = mic is live.
- **OFF AIR** (gray pill) = mic is muted.
- **Left-click** the pill to toggle. **Right-click** for the menu.
- **Global hotkey** (default ⇧⌘M) toggles from any app.

Muting flips the input device's hardware mute flag via CoreAudio, so it applies
system-wide and does **not** record or transmit any audio.

Requires **macOS 13 (Ventura) or later**.

## Build (Xcode)

Create the app project in Xcode and drop in the sources from this repo.

1. **File → New → Project → macOS → App.** Set:
   - Product Name: `muteMe`
   - Organization Identifier: `com.ardacanbakis` (Bundle ID becomes `com.ardacanbakis.muteMe`)
   - Interface: SwiftUI, Language: Swift
2. Delete the template's `muteMeApp.swift` and `ContentView.swift`.
3. Add the files from `Sources/muteMe/` to the target (Copy items if needed):
   `AppDelegate.swift`, `StatusItemController.swift`, `PillRenderer.swift`,
   `MicMuteController.swift`, `HotKeyManager.swift`, `LaunchAtLogin.swift`,
   `PreferencesView.swift`.
4. **File → Add Package Dependencies…** →
   `https://github.com/sindresorhus/KeyboardShortcuts` (Up to Next Major from 2.0.0).
5. Target **Info** tab: add **Application is agent (UIElement) = YES** and a
   **Privacy - Microphone Usage Description** string.
6. Target **Signing & Capabilities**: set your Team, add **App Sandbox**, and
   enable **Audio Input** under it.
7. Build & run (⌘R). The app is menubar-only — look for the **ON AIR** pill in
   the menu bar.

## Project layout

```
Sources/muteMe/
  AppDelegate.swift         App entry point, window + controller wiring
  StatusItemController.swift Menubar item, click routing, context menu
  PillRenderer.swift        Draws the ON AIR / OFF AIR pill
  MicMuteController.swift   CoreAudio mute + device-switch handling + fallback
  HotKeyManager.swift       Global shortcut registration
  LaunchAtLogin.swift       SMAppService login-item toggle
  PreferencesView.swift     SwiftUI settings (shortcut, launch at login)
```

## Distribution

### Homebrew (Developer ID + notarized)

1. Archive a Release build in Xcode (Product → Archive).
2. Sign with your **Developer ID Application** certificate and enable
   **Hardened Runtime** in the target's build settings.
3. Notarize and staple:
   ```sh
   xcrun notarytool submit muteMe.zip --keychain-profile "AC_PROFILE" --wait
   xcrun stapler staple muteMe.app
   ```
4. Package as a DMG and publish a Homebrew **Cask** pointing at the release.

### App Store (later)

With App Sandbox + the `device.audio-input` entitlement enabled, switch the
target to App Store provisioning and submit — no source changes needed.

