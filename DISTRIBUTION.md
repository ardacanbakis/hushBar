# Distributing HushBar

This guide covers every way to get HushBar onto other people's Macs, from a
quick build for a friend to a notarized DMG and a Homebrew cask. All commands
run **on a Mac** — the project can't be built on Linux.

> Throughout, replace `ardacanbakis` with your GitHub username, `AC_PROFILE`
> with your `notarytool` keychain profile name, and `TEAMID` with your Apple
> Developer Team ID.

---

## Contents

- [0. One-time setup](#0-one-time-setup)
- [1. Build the .app](#1-build-the-app)
- [2. Quick share (unsigned, for yourself or a friend)](#2-quick-share-unsigned-for-yourself-or-a-friend)
- [3. Sign + notarize (required for public distribution)](#3-sign--notarize-required-for-public-distribution)
- [4. Option A — DMG on GitHub Releases](#4-option-a--dmg-on-github-releases)
- [5. Option B — Homebrew Cask](#5-option-b--homebrew-cask)
- [6. Option C — Mac App Store](#6-option-c--mac-app-store)
- [7. Troubleshooting distribution](#7-troubleshooting-distribution)

---

## 0. One-time setup

You need these once per machine:

```sh
brew install xcodegen create-dmg
```

For any **public** distribution (Options A and B) you also need:

- A paid **Apple Developer Program** membership ($99/yr). The free tier can run
  the app locally but cannot notarize, so Gatekeeper will block other users.
- A **Developer ID Application** certificate. In Xcode:
  **Settings → Accounts → (your team) → Manage Certificates → + → Developer ID
  Application**.
- A `notarytool` credential profile stored in your keychain, so you don't paste
  your password every time:
  ```sh
  xcrun notarytool store-credentials "AC_PROFILE" \
    --apple-id "you@example.com" \
    --team-id "TEAMID" \
    --password "app-specific-password"
  ```
  The password is an **app-specific password** from
  [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security →
  App-Specific Passwords. It is **not** your Apple ID password.

Find your Team ID with:

```sh
xcrun altool --list-providers -u "you@example.com" -p "app-specific-password"
```

---

## 1. Build the .app

The repo ships with a build script that handles everything. From the repo root:

```sh
bash scripts/build-release.sh
```

This runs `xcodegen generate`, builds a Release `.app`, and writes to `dist/`:
- `HushBar-1.0.zip` — drag-to-Applications zip (always produced)
- `HushBar-1.0.dmg` — DMG with drag layout (produced if `create-dmg` is installed)

For a **signed + notarized** build (required for public distribution), set `SIGN=1` and export your notarytool profile name:

```sh
SIGN=1 AC_PROFILE="AC_PROFILE" bash scripts/build-release.sh
```

The script also prints the DMG's SHA-256 at the end — you'll paste that into the Homebrew cask.

**Manual Xcode route (alternative):**
```sh
xcodegen generate
open hushBar.xcodeproj
```
Select the **hushBar** scheme → **My Mac** → **Product → Archive → Distribute App → Developer ID → Export**. The exported folder contains `HushBar.app`.

---

## 2. Quick share (unsigned, for yourself or a friend)

The build script always produces `dist/HushBar-1.0.zip` — just send that file.
No `SIGN=1` needed; a free Apple ID with "Sign to Run Locally" is sufficient.

The recipient must **right-click → Open** the first time to bypass Gatekeeper's
"unidentified developer" warning. Or they can run:

```sh
xattr -dr com.apple.quarantine /Applications/HushBar.app
```

This is fine for a friend but not acceptable for public distribution — use
Option A or B for that.

---

## 3. Sign + notarize (required for public distribution)

Gatekeeper on other Macs will refuse to open an app that isn't signed with a
Developer ID **and** notarized by Apple. Do this once per release.

The export in step 1 already signs with Developer ID and enables Hardened
Runtime (set via `ENABLE_HARDENED_RUNTIME: YES` in `project.yml`). Verify:

```sh
codesign --verify --deep --strict --verbose=2 HushBar.app
spctl -a -vvv -t install HushBar.app    # may say "rejected" until notarized
```

Notarize the app. Notary service needs a zip or DMG; we'll zip for the check,
then staple the ticket:

```sh
ditto -c -k --keepParent HushBar.app HushBar-notarize.zip

xcrun notarytool submit HushBar-notarize.zip \
  --keychain-profile "AC_PROFILE" --wait

xcrun stapler staple HushBar.app
```

`--wait` blocks until Apple finishes (usually a few minutes). On success,
`stapler staple` attaches the ticket so the app validates even offline. Confirm:

```sh
spctl -a -vvv -t install HushBar.app    # should now say "accepted"
```

---

## 4. Option A — DMG on GitHub Releases

The simplest experience for non-technical users: download, drag, done.

**4.1 Build the DMG** (with the drag-to-Applications layout):

```sh
create-dmg \
  --volname "HushBar" \
  --window-size 520 320 \
  --icon "HushBar.app" 140 150 \
  --app-drop-link 380 150 \
  "HushBar-1.0.dmg" \
  "HushBar.app"
```

**4.2 Notarize and staple the DMG itself** (notarizing the app isn't enough —
staple the DMG too so the download validates):

```sh
xcrun notarytool submit "HushBar-1.0.dmg" \
  --keychain-profile "AC_PROFILE" --wait
xcrun stapler staple "HushBar-1.0.dmg"
```

**4.3 Publish a GitHub Release:**

1. Tag the release on the active branch:
   ```sh
   git tag v1.0
   git push origin v1.0
   ```
2. On GitHub: **Releases → Draft a new release → choose tag `v1.0`**.
3. Drag `HushBar-1.0.dmg` into the **Attach binaries** area.
4. Write release notes and **Publish release**.

Users now download the DMG from your Releases page, open it, and drag HushBar to
Applications. The direct download URL — needed for the Homebrew cask below — is:

```
https://github.com/ardacanbakis/hushBar/releases/download/v1.0/HushBar-1.0.dmg
```

---

## 5. Option B — Homebrew Cask

Lets power users install with one command. It points at the same DMG you
published in Option A, so do Option A first.

**5.1 Create a tap** — a public GitHub repo named exactly
`homebrew-tap` (the `homebrew-` prefix is required; users reference it as
`ardacanbakis/tap`):

```sh
# Create the repo on github.com first, then:
git clone https://github.com/ardacanbakis/homebrew-tap.git
cd homebrew-tap
mkdir -p Casks
```

**5.2 Copy the cask template** from this repo into your tap:

```sh
cp /path/to/hushBar/Casks/hushbar.rb Casks/hushbar.rb
```

Open `Casks/hushbar.rb` and replace `PASTE_SHA256_HERE` with the SHA-256
printed by the build script, or compute it manually:

```sh
shasum -a 256 dist/HushBar-1.0.dmg
```

**5.4 Commit and push:**

```sh
git add Casks/hushbar.rb
git commit -m "Add HushBar 1.0 cask"
git push
```

**5.5 Users install with:**

```sh
brew install --cask ardacanbakis/tap/hushbar
```

Or add the tap once and install by short name:

```sh
brew tap ardacanbakis/tap
brew install --cask hushbar
```

**Updating later:** bump `version` and `sha256` in the cask after publishing a
new Release; users get it via `brew upgrade --cask hushbar`.

You can lint the cask before pushing:

```sh
brew audit --cask --new ./Casks/hushbar.rb
brew install --cask ./Casks/hushbar.rb   # local test install
```

---

## 6. Option C — Mac App Store

More reach and automatic updates, but requires re-enabling the sandbox and
passing App Review.

1. **Re-enable the App Sandbox.** In `project.yml`, under the target's
   `entitlements.properties`, add:
   ```yaml
   com.apple.security.app-sandbox: true
   com.apple.security.device.audio-input: true
   ```
   Regenerate: `xcodegen generate`.

   > Note: the sandbox can virtualize CoreAudio device writes. Test muting
   > thoroughly under the sandbox before submitting — this is why Homebrew
   > builds keep the sandbox **off**.

2. In Xcode, switch the target's signing to your **App Store** provisioning
   (Automatic signing with your team usually handles this).
3. **Product → Archive → Distribute App → App Store Connect → Upload**.
4. In [App Store Connect](https://appstoreconnect.apple.com): create the app
   record, fill in metadata, attach the build, and submit for review.
5. Justify the microphone usage string in the review notes: HushBar only
   *toggles the device mute flag* and never opens a capture session.

---

## 7. Troubleshooting distribution

- **"App is damaged and can't be opened"** on a downloaded build → it wasn't
  notarized/stapled, or the DMG itself wasn't stapled. Redo step 3 and 4.2.
- **`notarytool` returns `Invalid`** → run
  `xcrun notarytool log <submission-id> --keychain-profile "AC_PROFILE"` to see
  the exact reason (commonly: Hardened Runtime missing, or an unsigned nested
  binary).
- **`spctl` says "rejected"** even after notarizing → you probably forgot
  `stapler staple`, or you stapled the `.app` but not the `.dmg`.
- **`brew install` fails with checksum mismatch** → the DMG on Releases differs
  from the `sha256` in the cask. Recompute with `shasum -a 256` and update the
  cask.
- **Cask name rules** → the tap repo must be `homebrew-tap`; the cask file and
  token must be lowercase (`hushbar`).
