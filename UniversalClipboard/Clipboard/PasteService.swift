import AppKit
import Carbon.HIToolbox

/// Puts history items back on the clipboard and pastes them into the frontmost app.
@MainActor
final class PasteService {
    /// Called after every write, so the monitor can skip the app's own change.
    var onWrite: (() -> Void)?

    private let store: HistoryStore
    private let pasteboard: NSPasteboard

    init(store: HistoryStore, pasteboard: NSPasteboard = .general) {
        self.store = store
        self.pasteboard = pasteboard
    }

    /// Writes `item` to the clipboard (only its plain text when `plainText` is set) and moves it to the top.
    @discardableResult
    func copy(_ item: ClipItem, plainText: Bool) -> Bool {
        let pasteboardItem = NSPasteboardItem()
        let types = item.kind == .text && plainText ? [NSPasteboard.PasteboardType.string.rawValue] : item.storedTypes
        var wroteSomething = false
        for type in types {
            guard let data = store.data(for: item, type: type) else { continue }
            pasteboardItem.setData(data, forType: NSPasteboard.PasteboardType(type))
            wroteSomething = true
            // Many apps only read TIFF images from the clipboard.
            if item.kind == .image, let tiff = NSBitmapImageRep(data: data)?.tiffRepresentation {
                pasteboardItem.setData(tiff, forType: .tiff)
            }
        }
        guard wroteSomething else { return false }

        pasteboard.clearContents()
        pasteboard.writeObjects([pasteboardItem])
        onWrite?()
        store.moveToTop(item.id)
        return true
    }

    /// Sends ⌘V to the frontmost app. Needs Accessibility permission; without it macOS drops the events.
    static func postPasteShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Ignore keys the user is still holding (e.g. Shift from Shift+Return) while the shortcut is sent.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let keyCode = KeyboardLayout.keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
        // 0x08 is the left-⌘ device flag; some apps check it as well as the generic ⌘ flag.
        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x08)
        for isKeyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isKeyDown)
            event?.flags = flags
            event?.post(tap: .cgSessionEventTap)
        }
    }
}
