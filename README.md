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

## Build

This repo defines the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
so the project file stays clean and reviewable in git.

```sh
brew install xcodegen
xcodegen generate      # creates muteMe.xcodeproj
open muteMe.xcodeproj
```

Then build & run from Xcode (⌘R). The `KeyboardShortcuts` Swift package is
resolved automatically.

> The project file is generated and git-ignored — re-run `xcodegen generate`
> after pulling changes to `project.yml`.

## Project layout

```
project.yml                 XcodeGen spec (target, signing, deps, Info.plist keys)
Support/Info.plist          LSUIElement (menubar-only), usage strings
Support/muteMe.entitlements App Sandbox + audio-input (App-Store-ready)
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

1. Archive a Release build in Xcode (Product → Archive) or via `xcodebuild`.
2. Sign with your **Developer ID Application** certificate (Hardened Runtime is
   already enabled in `project.yml`).
3. Notarize and staple:
   ```sh
   xcrun notarytool submit muteMe.zip --keychain-profile "AC_PROFILE" --wait
   xcrun stapler staple muteMe.app
   ```
4. Package as a DMG and publish a Homebrew **Cask** pointing at the release.

### App Store (later)

The code is already sandboxed with the `device.audio-input` entitlement. Switch
the target to App Store provisioning and submit — no source changes needed.
