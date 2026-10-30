import AppKit
import ApplicationServices

@MainActor
enum Permissions {
    enum ClipboardAccess {
        case allowed
        /// macOS asks before each background read (Paste from Other Apps is set to Ask).
        case ask
        case denied
    }

    /// Needed to send ⌘V to other apps.
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that leads to Privacy & Security › Accessibility.
    static func requestAccessibility() {
        // The string value of kAXTrustedCheckOptionPrompt; the imported global is not concurrency-safe.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// The "Paste from Other Apps" setting (macOS 15.4+) for reading the clipboard in the background.
    static var clipboardAccess: ClipboardAccess {
        if #available(macOS 15.4, *) {
            switch NSPasteboard.general.accessBehavior {
            case .ask: return .ask
            case .alwaysDeny: return .denied
            default: return .allowed
            }
        }
        return .allowed
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openClipboardSettings() {
        // "Paste from Other Apps" has no documented anchor; unknown anchors fall back to Privacy & Security.
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard")
    }

    private static func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
