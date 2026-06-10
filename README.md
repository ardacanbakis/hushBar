# HushBar — macOS

**Mute your microphone from the menu bar — globally, instantly, across every app.**

> **Windows version:** [ardacanbakis/hushBar-windows](https://github.com/ardacanbakis/hushBar-windows)

HushBar lives entirely in the menu bar (no Dock icon, no window). One click or a global keyboard shortcut mutes or unmutes your mic system-wide, because it flips the actual hardware mute flag on your audio device — not just a per-app setting. Every app sees it at once.

---

## Features

- **One-click global mute** — left-click the badge to toggle. Affects Zoom, FaceTime, browsers, everything simultaneously.
- **Global keyboard shortcut** — default ⇧⌘M, rebindable, works from any app without switching focus.
- **5 badge shapes** — Pill, Rounded Rectangle, Rectangle, Toggle Switch, Microphone icon (with mute slash).
- **12 built-in presets** — ON AIR, LIVE/Hushed, Podcast, Office/Meetings, Streamer, Minimal, and more. Fully editable.
- **Full style customization** — rename On/Off labels, pick badge fill colors, text colors, font size (S/M/L/XL), bold or regular, letter case.
- **Live style preview** — the editor shows exactly how your badge looks in the real menu bar as you edit.
- **Stays in sync** — listens for external mic state changes (another app, macOS Control Center) and updates the indicator to match.
- **Launch at login** toggle.
- **Sound feedback** — optional system sound on each toggle (8 choices).
- **Privacy-first** — muting toggles a device flag. No audio stream is ever opened; nothing is recorded or transmitted.

---

## How to use

- **Left-click** the badge → toggle mute/unmute.
- **Right-click** (or control-click) → context menu with Mute/Unmute, Preferences, Launch at Login, Quit.
- **⇧⌘M** (default) → toggle from any app.
- **Preferences** → three tabs:
  - **General** — shortcut, toggle sound, font size/style, active preset summary, mic status.
  - **Style** — select, create, edit, and preview presets; custom color panel on the right.
  - **About** — credits, links, donation.

> **One app at a time.** Apps like MicDrop or Krisp register their own hardware listeners and will fight HushBar for control. Quit them; run one mic-mute app at a time.

---

## How it works

HushBar is an AppKit "agent" app (`LSUIElement`) — no Dock icon, no main window.

- **Muting** (`MicMuteController.swift`) uses CoreAudio. It resolves the default input device and writes `kAudioDevicePropertyMute` across all input elements. Because this is the device's own hardware flag, the change is system-wide and no audio stream is ever opened.
- **Staying in sync** — property listeners on the default-device-change and the mute flag keep the indicator honest. The app reads back the real hardware state after every write rather than trusting the return code.
- **Menu bar rendering** (`PillRenderer.swift`) — all badge shapes are drawn programmatically with `NSBezierPath`; no image assets.
- **Global shortcut** (`HotKeyManager.swift`) — [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) package; Carbon-backed, no Accessibility permission required.
- **Settings** (`AppSettings.swift`) — presets and prefs persisted as JSON + scalars in `UserDefaults`. Forward-compatible: new fields use `decodeIfPresent` so old preset data is preserved across updates.

### Why microphone permission?

For CoreAudio writes to affect real hardware (not a virtualized per-process copy), macOS requires the app to be authorized for the microphone. HushBar requests this at launch but never opens a capture session.

---

## Project layout

```
project.yml                     XcodeGen spec (targets, signing, deps)
Support/Info.plist              LSUIElement flag, mic usage description
Support/hushBar.entitlements    audio-input entitlement (sandbox off for Developer ID)
Sources/hushBar/
  AppDelegate.swift             Entry point, mic-permission request, preferences window
  MoveToApplications.swift      Offers to move into /Applications on first launch
  MicMuteController.swift       CoreAudio mute + listeners + intent re-assertion
  StatusItemController.swift    NSStatusItem, click routing, context menu
  PillRenderer.swift            Draws all badge shapes via NSBezierPath
  AppSettings.swift             BarPreset, FontSize, ToggleSound, UserDefaults persistence
  PreferencesView.swift         SwiftUI prefs window (General / Style / About)
  ColorEditorPanel.swift        Custom inline color picker (palette + RGB + hex)
  HotKeyManager.swift           Global shortcut via KeyboardShortcuts
  LaunchAtLogin.swift           SMAppService login-item toggle
  BrandIcons.swift              Hand-built vector social icons for the About tab
  DebugLogger.swift             hushLog() wrapper (NSLog shim)
docs/
  index.html                    Project website (GitHub Pages)
```

---

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) to build from source

---

## Building from source

```sh
brew install xcodegen
git clone https://github.com/ardacanbakis/hushBar.git
cd hushBar
xcodegen generate
open hushBar.xcodeproj
```

Select the **hushBar** scheme → **My Mac** → **⌘R**. The app has no Dock icon — look for the badge in the top-right menu bar.

> Re-run `xcodegen generate` after pulling changes to `project.yml` or when source files are added or removed.

Full distribution instructions (signing, notarization, DMG, Homebrew cask) are in [DISTRIBUTION.md](DISTRIBUTION.md).

---

## Credits

Created by [Arda Canbakis](https://ardacanbakis.com) · [ardacanbakis.github.io/hushBar](https://ardacanbakis.github.io/hushBar/)
