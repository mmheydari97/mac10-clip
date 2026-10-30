# Universal Clipboard

A small macOS menu-bar clipboard history. Press **⇧⌘V** to see the last things you copied (text and images) and pick one to paste. Copies made on your other Macs, iPhone or iPad show up as well, through Apple's Universal Clipboard.

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
- Wi-Fi, Bluetooth and Handoff are on (System Settings › General › AirDrop & Handoff);
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

## Building

Needs Xcode 16 or later (built with Xcode 27) and macOS 14 or later.

```sh
xcodegen generate     # only after editing project.yml (brew install xcodegen)
xcodebuild -project UniversalClipboard.xcodeproj -scheme UniversalClipboard \
  -configuration Release -derivedDataPath build/DerivedData build
ditto build/DerivedData/Build/Products/Release/UniversalClipboard.app /Applications/UniversalClipboard.app
```

Tests: `xcodebuild test -project UniversalClipboard.xcodeproj -scheme UniversalClipboard -destination 'platform=macOS'`

**Signing:** builds use the Apple Development certificate of team `KSKVWTF4A8`.
- The app has no provisioning profile, so builds never expire; you only rebuild when you change the code.
- Keep using the same certificate, not "Sign to Run Locally". macOS ties the Accessibility permission to the signature, and an ad-hoc build loses it on every rebuild.

**Another Mac:**
- *Copy the built app over.* If macOS blocks it, go to System Settings › Privacy & Security and click Open Anyway.
- *Build it there.* Use the same Apple ID in Xcode, or change `DEVELOPMENT_TEAM` in `project.yml`.

## Troubleshooting

- **App logs:**
  - Command: `log show --last 1h --predicate 'subsystem == "com.kian.UniversalClipboard"'`
  - Logs the permission state at launch.
  - Logs the clipboard types of each item that arrived from another device.
- **⇧⌘V conflicts:** the shortcut overrides ⇧⌘V in every app, e.g. "paste without formatting" in Slack or Google Docs and Markdown preview in VS Code. Change it in Settings, or use Shift+Return in the list for plain text.
- **Accessibility looks on but pasting doesn't work:** this usually happens after the app was re-signed differently. Remove the app from the Accessibility list, then add it again.
