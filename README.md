# Universal Clipboard

A small macOS menu-bar clipboard history. Press **⇧⌘V** to see the last things you copied (text and images) and pick one to paste. Copies made on your other Macs, iPhone or iPad show up as well, through Apple's Universal Clipboard.

## Install on a Mac

### What you need

- macOS 14 (Sonoma) or later.
- Xcode 16 or later from the App Store. Open it once so it can accept its license and install its components.

You don't need an Apple ID, XcodeGen or Homebrew; the Xcode project is in the repo.

### Build and install

Paste this into Terminal:

```sh
git clone https://github.com/mmheydari97/mac10-clip.git
cd mac10-clip
./install.sh
```

The script builds the app, signs it, checks the signature, replaces any running copy in `/Applications` and opens it.

A clipboard icon appears in the menu bar and the Settings window opens. Then:

1. Click **Open System Settings** next to *Accessibility* and turn on Universal Clipboard. This lets it paste for you.
2. Turn on **Launch at login** so it keeps recording after a restart.
3. Make sure Handoff is on (System Settings › General › AirDrop & Handoff) if you want copies from your other devices.

### How the app is signed

`install.sh` signs the app with a self-signed certificate called *UniversalClipboard Local Signing*. The script creates it in your login keychain on the first run; the first time, macOS may ask whether `codesign` can use the key (click **Always Allow**).

Don't sign it with an Xcode *Apple Development* certificate instead. Xcode replaces those certificates on its own, for example when you build on another Mac, and revokes the old one. macOS then treats any app signed with the revoked certificate as malware and moves it to the Trash, often after a macOS update or restart. Apple can't revoke a self-signed certificate. The signature also stays the same across rebuilds, so the Accessibility permission survives updates.

### Without Xcode: copy the app from another Mac

1. On a Mac that already has it, zip it with `ditto -c -k --keepParent /Applications/UniversalClipboard.app ~/Desktop/UniversalClipboard.zip`.
2. Send the zip to the other Mac (AirDrop works), unzip it, and move **UniversalClipboard.app** to Applications.
3. Open it. If macOS blocks it, go to System Settings › Privacy & Security and click **Open Anyway**.

### Updating

```sh
cd mac10-clip
git pull
./install.sh
```

Your history and permissions are kept.

## Using it

| Key | Action |
|---|---|
| ⇧⌘V | Open the list at the mouse pointer (press again to close) |
| ↑ / ↓, then Return | Paste the selected item into the app you were using |
| 1–9 | Paste that item directly |
| Shift + any of the above, or Shift-click | Paste as plain text (formatting removed) |
| Esc, or click elsewhere | Close |

Items marked with the laptop-and-phone icon came from another device.

The menu-bar icon has **Show History**, **Clear History**, **Settings…** and **Quit**. In Settings you can:
- change the shortcut;
- choose how many items to keep (10 / 20 / 50 / 100);
- turn off **Paste automatically**, so choosing an item only copies it;
- enable **Launch at login**;
- see whether the permissions are granted.

## Permissions

- **Accessibility** (System Settings › Privacy & Security › Accessibility) lets the app press ⌘V for you. Without it, choosing an item only copies it and you press ⌘V yourself.
- **Paste from Other Apps** (System Settings › Privacy & Security) controls whether apps can read the clipboard in the background. If macOS asks or blocks, allow Universal Clipboard there; the menu shows a warning when this is the problem.

## Copies from other devices

The app doesn't sync anything itself. macOS's Universal Clipboard hands each new copy to your nearby devices, and the app records what arrives. This works when:
- the devices are signed into the same Apple ID;
- Wi-Fi, Bluetooth and Handoff are on;
- the devices are near each other and awake.

Each Mac keeps its own history, so install the app on every Mac you want a history on. Things copied while a Mac was asleep or away won't appear on that Mac. macOS doesn't say *which* device sent an item, so those items only show the other-device icon.

## What is recorded

- **Text**, including formatting (RTF/HTML) so pasting keeps it, and **images** (PNG, JPEG, HEIC, TIFF; TIFF is stored as PNG).
- **Skipped:**
  - anything password managers mark as secret or temporary;
  - Finder file copies;
  - whitespace-only text;
  - items over 25 MB.
- Copying something that's already in the history moves it to the top instead of adding it twice.
- History stays on the Mac it was recorded on, in `~/Library/Application Support/com.kian.UniversalClipboard/`. **Clear History** deletes it.

## Development

- **Tests:** `xcodebuild test -project UniversalClipboard.xcodeproj -scheme UniversalClipboard -destination 'platform=macOS'`
- **Regenerating the project:** `UniversalClipboard.xcodeproj` is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After editing `project.yml`, run `brew install xcodegen`, then `xcodegen generate`, and commit both files.
- **Signing:** the project is set to sign with an Apple Development certificate (team `KSKVWTF4A8`), which is fine for running from Xcode. Use `./install.sh` for the copy in `/Applications` (see [How the app is signed](#how-the-app-is-signed)). Don't use "Sign to Run Locally" either: macOS ties the Accessibility permission to the signature, and an ad-hoc build loses it on every rebuild.

## Troubleshooting

- **`xcodebuild` says it requires Xcode, or that the license isn't accepted:** run `sudo xcode-select -s /Applications/Xcode.app`, then open Xcode once.
- **macOS said the app contains malware and moved it to the Trash:** it was signed with an Apple Development certificate that has since been revoked. Run `./install.sh` and turn on Accessibility again. To check an app's signature, run `codesign --verify --strict -v /Applications/UniversalClipboard.app`. If it prints `CSSMERR_TP_CERT_REVOKED`, the certificate was revoked.
- **App logs:**
  - Command: `log show --last 1h --predicate 'subsystem == "com.kian.UniversalClipboard"'`
  - Logs the permission state at launch.
  - Logs the clipboard types of each item that arrived from another device.
- **⇧⌘V conflicts:** the shortcut overrides ⇧⌘V in every app, e.g. "paste without formatting" in Slack or Google Docs and Markdown preview in VS Code. Change it in Settings, or use Shift+Return in the list for plain text.
- **Accessibility looks on but pasting doesn't work:** this usually happens after the app was re-signed differently. Remove the app from the Accessibility list, then add it again.
