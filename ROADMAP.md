# HushBar — Development Roadmap & Decision Log

This doc records every major design decision, path taken, and hard-won knowledge from the project. It's for future maintainers and for revisiting architectural choices.

---

## Architecture

### AppKit + SwiftUI hybrid
macOS menu bar apps require NSStatusItem (AppKit-only). `.accessory` activation policy is also AppKit. SwiftUI is used only for the Preferences window. This hybrid gives full control over the menu bar while allowing modern UI in settings.

### No App Sandbox
Discovered the hard way: with App Sandbox enabled, CoreAudio writes return status=0 (success) but affect only a virtualized per-process device — the real hardware mute flag never changes. Muting appears to work but doesn't. The sandbox is permanently OFF for Developer ID / Homebrew builds. Must be re-enabled only for App Store submission, with thorough testing.

### CoreAudio direct device flag (not audio capture)
We could have used AVAudioSession to simulate muting by not routing audio. Chose CoreAudio `kAudioDevicePropertyMute` because it's truly system-wide — every app sees the muted mic. No audio stream is ever opened, so no recording occurs. Requires the microphone TCC permission anyway (even without capturing) for the writes to affect real hardware.

### Preset system
Evolved from single hardcoded colors/labels to:
1. `BarPreset` struct: name, shape, on/off text, on/off colors, text case
2. Added `onTextColor`/`offTextColor` separate from badge fill
3. Added `FontSize` enum (S/M/L = 9/11/13pt) as a global setting
4. 4 default presets → 12 default presets (ON AIR, Streaming, Podcast, Creator, Office, ON CALL, Gamer, Minimal, Mic Icon)
5. `BarPreset.init(from:)` uses `decodeIfPresent` for all newer fields to preserve existing user presets when new fields are added (forward-compatible Codable)

---

## Feature Development Log

### Phase 1 — Core App
- AppDelegate with `.accessory` activation policy (no Dock icon)
- `MicMuteController`: CoreAudio mute applied across multiple candidate elements (element 0 + channels 1, 2)
- `NSStatusItem` with `PillRenderer` (image-based, not template image)
- Shapes: pill (capsule), roundedRect, rectangle, toggleSwitch
- Single preset with hardcoded colors

### Phase 2 — Settings UI Overhaul
**Problem**: Original settings had a `TopHalf` wrapper centering content in the top half of a fixed window, leaving large empty space. Preset editing was split across disconnected tabs.

**Decisions:**
- Removed `TopHalf` wrapper; tabs fill naturally
- Enlarged window to 720×600 base (936 when color panel showing)
- Style tab: master-detail layout — preset list sidebar + editor panel
- Sidebar: 240px default, draggable (140–340px) via `DragGesture` + `NSCursor.resizeLeftRight.push()/pop()` on hover
- Live preview strip at top of editor (dark background simulating the real menu bar)
- Custom `ColorEditorPanel` overlay instead of native `NSColorPanel`. The native panel opens wherever macOS places it (uncontrolled). Custom panel slides in from the trailing edge with `.transition(.move(edge: .trailing))`. Window expands from 720 → 936 when active.

### Phase 3 — Feature Expansion

**Text colors per state:** Users needed different text colors for on/off badge states. Added `onTextColor`/`offTextColor` to `BarPreset` with `decodeIfPresent` for backward compatibility.

**Font size setting:** Global `FontSize` enum (small/medium/large = 9/11/13pt). Not per-preset — all presets share the size setting.

**Microphone icon shape:** New `BarShape.mic`. Rendered in `PillRenderer.micImage()` with: capsule body (`NSBezierPath` roundedRect), U-bracket arc (`appendArc`), stem + base lines, red diagonal slash when muted. Empty `onText`/`offText` so no text renders.

**12 default presets:** Classic radio, streaming, podcast/creator, office/meetings, streamer/gamer, minimal/monochrome, mic icon.

**Window polish:** `window.orderFrontRegardless()` so Settings always comes to front. Adaptive window background: `NSColor(name: nil) { appearance in ... }` (the `name: nil` is intentional — no registered name needed, just a dynamic color).

**About tab redesign:** New order: logo (tappable → website) → tagline/version → "Created with ♥ by [animated name]" → divider → donation paragraph → Buy Me a Coffee → social links. `DancingName` component: letter-by-letter sine-wave offset + rainbow gradient + `hueRotation(.degrees(t * 60))`.

**General tab footer:** "Check my stuff →" neon animated button that navigates to About tab.

**Website (docs/index.html):** Animated SVG mic demo (auto-toggles LIVE↔Hushed every 3.5s), scroll-to-top button.

---

## Bug Hunt: Mute Oscillation (Major Investigation)

Symptom: after muting, the mic would immediately unmute and the app would oscillate indefinitely between muted/unmuted states with sounds playing on each flip.

Multiple root causes discovered in sequence via an in-app debug logger.

### Bug 1 — NSSound "Already playing" spam
`NSSound(named:)` returns a shared cached instance. Calling `.play()` while already playing floods Console with "Already playing" errors and potentially interferes with state tracking.
**Fix:** `guard !sound.isPlaying else { return }` in `ToggleSound.play()`.

### Bug 2 — vol=0 write clears hardware mute
Original code: after setting hardware mute, also set volume=0 as a fallback for devices that don't honor the mute flag. On MacBook Air Mic (device ID 79), element 0 has both mute AND volume capability. Writing vol=0 to an already-muted element causes the audio driver to clear the hardware mute flag. The driver treats vol=0 as "reclaim volume control → unmute".

This triggered the mute property listener → `readMuted()=false` → state flip → sound plays → loop.

**Fix:** Track which elements confirmed hardware mute via readback (`hwMuted: Set`). Skip volume fallback for those elements only.

### Bug 3 — Spurious `handleDefaultDeviceChanged` notification
When macOS grants TCC microphone permission, it fires `kAudioHardwarePropertyDefaultInputDevice` even when device ID hasn't changed (79→79). The handler was re-applying `setMuted(intended)` unconditionally, which could retrigger the loop.
**Fix:** `guard newID != deviceID else { return }` — skip re-apply if device didn't actually change.

### Bug 4 — macOS audio daemon clears mute within ~40ms
After Bugs 1–3 were fixed, a new pattern emerged from debug logs: write succeeds, but ~40ms later the hardware mute is cleared by something external (no user action). Identified as macOS's own audio policy daemon reacting to our write.

**Fix:** Pre-queue a suppression block on `listenerQueue` before each write. Both the suppression block and the post-write listener callback are on the same serial queue, so order is guaranteed (suppression runs first). Listener checks `suppressListenerUntil`; if within 400ms, ignores the callback.

### Bug 5 — Fast-toggle exposes 3.83-second daemon cycle
The 400ms suppression handled the immediate (~40ms) daemon reaction. But the daemon also runs a periodic ~3.83-second re-sync cycle. After the suppression window expired, this periodic tick could fire and restart the oscillation.

**Trigger sequence (from real debug logs):**
1. User mutes → HW=1 ✓
2. Daemon unmutes → HW=0, listener suppressed ✓ (but hardware is now actually 0)
3. User fast-unmutes 1.4s later → writes HW=0 (already 0, no hardware change, no listener fires → no new suppression set)
4. 3.83s after step 1: daemon's periodic tick fires outside suppression window → `listener fired readback=1` → isMuted flips → daemon's immediate unmute reaction fires → `listener fired readback=0` → loop

**Fix:** Track `muteIntent` on `listenerQueue` (queued before each write, same serial queue guarantees it arrives before the listener callback). When `listener fired readback ≠ intent`: re-assert silently (suppress + write intent + updateMuted with readback). User never sees the flip — no state change, no sound.

---

## Debug Tooling Added

`DebugLogger.swift` — singleton `@Published entries: [LogEntry]`, `log()`, `allText()`.
`hushLog()` — replaces all `NSLog("hushBar: ...")` calls, routes to both system log and `DebugLogger`.
`DebugLogView` in Preferences — fourth "Debug" tab (🐜 ant icon) with live-scrolling monospaced log, timestamps, Clear, Copy buttons, orange "DEV ONLY" banner.

**To remove before first public release:**
- Remove `PrefsTab.debug` case from `PreferencesView.swift`
- Remove the `.debug` tab entry from the `TabView`
- Remove the `DebugLogView` struct (or keep it dormant)
- `DebugLogger.swift` can stay (harmless) or be deleted
- Replace `hushLog()` calls with plain `NSLog()` or remove them

---

## Known Constraints & Gotchas

1. **Only one mic-mute app at a time.** Competing apps register their own property listeners and re-assert their flag whenever ours changes. Last writer wins. Quit others before using HushBar.

2. **Mic TCC permission required even without capture.** Without it, macOS virtualizes CoreAudio writes to a per-process device.

3. **App Sandbox virtualizes CoreAudio writes.** Must be OFF. Discovered after initially building with sandbox enabled and finding mute "worked" (status=0) but didn't actually affect hardware.

4. **XcodeGen must be re-run** when adding/removing/renaming source files. The xcodeproj is gitignored. This has broken builds multiple times (AppSettings.swift, BrandIcons.swift, ColorEditorPanel.swift, DebugLogger.swift).

5. **`NSColor(name: nil) { appearance in ... }`** — the `name: nil` is intentional; you don't need a registered name to create a dynamic adaptive color. This is the correct pattern for macOS 10.15+.

6. **MacBook Air Mic (device ID 79):** element 0 has both mute and volume; elements 1 and 2 have neither. All effective mute operations are element-0-only for this device.

7. **macOS audio policy daemon** (~3.83s cycle) actively opposes mic mute writes. This is not a competing user-space app — it's macOS itself. The intent-based re-assertion mechanism was specifically designed for this.

---

## Distribution Status

| Channel | Status |
|---|---|
| Build from source (dev only) | ✅ Working |
| Unsigned zip (friend share) | ✅ Possible |
| Signed + notarized DMG | ⏳ Needs Apple Developer Program ($99/yr) |
| GitHub Release | ⏳ Needs signed build first |
| Homebrew Cask (`ardacanbakis/tap`) | ⏳ Needs: paid account + tap repo + first release |
| Mac App Store | ⏳ Needs: paid account + sandbox re-enabled + testing |

---

## Open Items

- [ ] Remove Debug tab before first public release
- [ ] Subscribe to Apple Developer Program
- [ ] Set up Developer ID Application certificate + notarytool keychain profile
- [ ] Create `github.com/ardacanbakis/homebrew-tap` repository
- [ ] First signed + notarized GitHub Release with DMG
- [ ] Add Homebrew cask at `Casks/hushbar.rb` in the tap repo
- [ ] Update README with install commands once Homebrew is live
