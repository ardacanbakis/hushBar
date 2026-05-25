# HushBar

A lightweight macOS menu bar app that mutes and unmutes your **microphone
globally** — across every app at once — with a single click or a global
keyboard shortcut. It never records or transmits any audio.

It lives entirely in the menu bar (no Dock icon, no window) and shows a small
toggle that mirrors your mic's real state.

---

## Features

- **One-click global mute** from the menu bar. Affects every app system-wide
  (Zoom, FaceTime, Photo Booth, browsers, etc.), because it flips the input
  device's actual hardware mute flag.
- **Two button styles**: an On/Off **toggle switch**, or the classic
  **ON AIR / OFF AIR** pill. Switchable in Preferences.
- **Editable labels & colors**: rename "On"/"Off" to anything (e.g.
  "Live"/"Muted") and pick your own colors.
- **Global hotkey** (default ⇧⌘M) to toggle from any app.
- **Launch at login** toggle.
- **Reflects external changes**: if another tool or macOS changes the mic state,
  HushBar's indicator updates to match.
- **Privacy-friendly**: muting just toggles a device flag — it never opens an
  audio stream, so no recording ever happens.

---

## Requirements

- **macOS 13 (Ventura) or later**
- **Xcode 15+** (to build it yourself)
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** (generates the Xcode
  project from `project.yml`)

---

## Getting it running on a new Mac

The Xcode project is generated from `project.yml` (and is git-ignored), so the
first step on any machine is to generate it.

```sh
brew install xcodegen
git clone https://github.com/ardacanbakis/mcdrop.git
cd mcdrop
xcodegen generate
open hushBar.xcodeproj
```

In Xcode:

1. Wait a few seconds for the **KeyboardShortcuts** Swift package to resolve
   (you'll see it fetch in the status bar).
2. *(Recommended)* Select the **hushBar** target → **Signing & Capabilities** →
   set **Team** to your Apple ID (a free account is fine). If you leave it as
   None, choose **Sign to Run Locally** if Xcode complains about signing.
3. Press **⌘R**.

The app has **no Dock icon** — look for the toggle in the **top-right menu bar**.
On first launch macOS will ask for **Microphone access**; click **Allow** (the
app doesn't record — this just authorizes it to control the device).

> Re-run `xcodegen generate` whenever you pull changes to `project.yml`, add or
> remove source files, or move to a new machine.

---

## How to use it

- **Left-click** the menu bar toggle → mute / unmute the mic.
- **Right-click** (or control-click) → menu with Mute/Unmute, Preferences,
  Launch at Login, and Quit.
- **Global shortcut** → press ⇧⌘M (rebindable) from any app to toggle.
- **Preferences** (right-click → Preferences) has three tabs:
  - **General** — global shortcut, launch at login, live mic status.
  - **Style** — button style, editable On/Off labels, colors, with a live
    preview.
  - **About** — links and credits.

> **Run only one mic-mute app at a time.** Tools like MicDrop *continuously
> re-assert* the same hardware mute flag HushBar uses. If two such apps run at
> once, they fight over the flag and neither wins reliably. Quit the others and
> HushBar controls the mic cleanly.

---

## How it works

HushBar is a small AppKit "agent" app (`LSUIElement`), meaning it has no Dock
icon or main window — just a menu bar item.

- **Muting** (`MicMuteController.swift`) uses **CoreAudio**. It finds the
  default input device (`kAudioHardwarePropertyDefaultInputDevice`) and sets the
  hardware mute flag (`kAudioDevicePropertyMute`) across the device's input
  elements, with input-volume-to-zero and global-scope fallbacks for devices
  that don't honor the mute flag. Because this is the device's own flag, the
  change is **system-wide** — every app sees the muted mic. Reading/writing this
  flag does **not** touch audio samples, so no microphone recording occurs.
- **Staying in sync**: it listens for changes to the default input device (so
  switching mics re-applies your state) and to the mute flag itself (so the
  indicator reflects external changes), then reads back the real state so the
  icon never lies.
- **Menu bar UI** (`StatusItemController.swift`, `PillRenderer.swift`): a custom
  `NSStatusItem` whose image is drawn per state and style; left-click toggles,
  right-click opens the menu.
- **Global hotkey** (`HotKeyManager.swift`): uses the
  [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
  package, which wraps Carbon hotkeys — no Accessibility permission required.
- **Launch at login** (`LaunchAtLogin.swift`): `SMAppService` (macOS 13+).
- **Settings** (`AppSettings.swift`): persisted in `UserDefaults`.

### Why microphone permission?

For our device writes to affect the **real** hardware (not a virtualized
per-process copy), macOS requires the app to be authorized for the microphone.
HushBar requests this once at launch but never opens an audio stream.

---

## Project layout

```
project.yml                   XcodeGen spec (target, signing, deps, Info.plist keys)
Support/Info.plist            LSUIElement (menu-bar-only), mic usage string
Support/hushBar.entitlements  device.audio-input (sandbox off for Developer ID builds)
Sources/hushBar/
  AppDelegate.swift           App entry point, mic-permission request, window wiring
  StatusItemController.swift  Menu bar item, click routing, context menu
  PillRenderer.swift          Draws the toggle-switch / ON AIR pill image
  MicMuteController.swift     CoreAudio mute + device/volume handling + listeners
  HotKeyManager.swift         Global shortcut registration
  LaunchAtLogin.swift         SMAppService login-item toggle
  AppSettings.swift           Persisted style/color/label settings
  PreferencesView.swift       SwiftUI tabbed settings (General / Style / About)
  BrandIcons.swift            Vector social icons for the About tab
```

---

## Distribution

HushBar can be shipped three ways:

- **DMG on GitHub Releases** — users download and drag to Applications.
- **Homebrew Cask** — `brew install --cask ardacanbakis/tap/hushbar`.
- **Mac App Store** — re-enable the sandbox and submit.

Full step-by-step instructions (signing, notarization, cask setup, App Store)
live in **[DISTRIBUTION.md](DISTRIBUTION.md)**.

---

## Troubleshooting

- **Toggling does nothing / mic still hot** → another mic-mute app (e.g.
  MicDrop) is running and re-asserting the flag. Quit it; run one at a time.
- **No menu bar item appears** → it's a menu-bar-only app; check the top-right.
  Make sure the build succeeded and is running.
- **macOS didn't ask for mic permission / muting won't stick** → enable it in
  **System Settings → Privacy & Security → Microphone → HushBar**.
- **Signing errors on build** → set a Team in Signing & Capabilities, or choose
  "Sign to Run Locally".

---

## Credits

Created by [Arda Canbakis](https://ardacanbakis.com).
