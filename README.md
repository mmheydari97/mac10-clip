# Universal Clipboard

A small macOS menu-bar clipboard history. Press **⇧⌘V** to see the last things you copied (text and images) and pick one to paste. Copies made on your other Macs, iPhone or iPad show up as well, through Apple's Universal Clipboard.

## Install on a Mac

### What you need

- macOS 14 (Sonoma) or later.
- Xcode 16 or later from the App Store. Open it once so it can accept its license and install its components.
- An Apple ID added to Xcode under **Xcode › Settings › Accounts** (a free account is enough).

You don't need XcodeGen or Homebrew; the Xcode project is in the repo.

### Build and install

Paste this into Terminal:

```sh
git clone https://github.com/mmheydari97/mac10-clip.git
cd mac10-clip
xcodebuild -project UniversalClipboard.xcodeproj -scheme UniversalClipboard \
  -configuration Release -derivedDataPath build/DerivedData -allowProvisioningUpdates build
osascript -e 'quit app id "com.kian.UniversalClipboard"' 2>/dev/null   # quits a running copy, if any
rm -rf /Applications/UniversalClipboard.app
ditto build/DerivedData/Build/Products/Release/UniversalClipboard.app /Applications/UniversalClipboard.app
open /Applications/UniversalClipboard.app
```

A clipboard icon appears in the menu bar and the Settings window opens. Then:

1. Click **Open System Settings** next to *Accessibility* and turn on Universal Clipboard. This lets it paste for you.
2. Turn on **Launch at login** so it keeps recording after a restart.
3. Make sure Handoff is on (System Settings › General › AirDrop & Handoff) if you want copies from your other devices.

### Signing with a different Apple ID

The project is set to sign with team `KSKVWTF4A8`.
- **Same account:** if Xcode on this Mac is signed into the Apple ID that owns that team, the commands above work as they are.
- **Different account:** add your team to the `xcodebuild` line, e.g. `... -allowProvisioningUpdates DEVELOPMENT_TEAM=ABCDE12345 build`. To find your team ID, open `UniversalClipboard.xcodeproj` in Xcode, select the *UniversalClipboard* target, and pick your team under **Signing & Capabilities**; Xcode then shows the ID and the project builds with it.

Either way, the app has no provisioning profile, so it never expires. You only rebuild to update it.

### Without Xcode: copy the app from another Mac

1. On a Mac that already has it, zip it with `ditto -c -k --keepParent /Applications/UniversalClipboard.app ~/Desktop/UniversalClipboard.zip`.
2. Send the zip to the other Mac (AirDrop works), unzip it, and move **UniversalClipboard.app** to Applications.
3. Open it. If macOS blocks it, go to System Settings › Privacy & Security and click **Open Anyway**.

### Updating

```sh
cd mac10-clip
git pull
```

Then run the `xcodebuild` line and the four lines after it again. Your history and permissions are kept.

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
- **Keep the same signing certificate:** don't switch to "Sign to Run Locally". macOS ties the Accessibility permission to the signature, and an ad-hoc build loses it on every rebuild.

## Troubleshooting

- **`xcodebuild` says it requires Xcode, or that the license isn't accepted:** run `sudo xcode-select -s /Applications/Xcode.app`, then open Xcode once.
- **Signing error about a missing certificate or team:**
  - Make sure an Apple ID is added in Xcode › Settings › Accounts.
  - Keep `-allowProvisioningUpdates` on the command line.
  - If your Apple ID isn't on team `KSKVWTF4A8`, see [Signing with a different Apple ID](#signing-with-a-different-apple-id).
- **App logs:**
  - Command: `log show --last 1h --predicate 'subsystem == "com.kian.UniversalClipboard"'`
  - Logs the permission state at launch.
  - Logs the clipboard types of each item that arrived from another device.
- **⇧⌘V conflicts:** the shortcut overrides ⇧⌘V in every app, e.g. "paste without formatting" in Slack or Google Docs and Markdown preview in VS Code. Change it in Settings, or use Shift+Return in the list for plain text.
- **Accessibility looks on but pasting doesn't work:** this usually happens after the app was re-signed differently. Remove the app from the Accessibility list, then add it again.
