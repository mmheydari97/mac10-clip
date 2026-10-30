import Observation

/// Permission status shown in the menu and in Settings.
@MainActor
@Observable
final class AppState {
    private(set) var accessibilityGranted = Permissions.isAccessibilityTrusted
    private(set) var clipboardAccess = Permissions.clipboardAccess
    /// Set when the clipboard listed data but refused to hand it over.
    var clipboardReadFailed = false

    var hasClipboardAccessProblem: Bool {
        clipboardAccess != .allowed || clipboardReadFailed
    }

    func refresh() {
        // Assign only on change so observers aren't woken every refresh.
        let accessibility = Permissions.isAccessibilityTrusted
        if accessibility != accessibilityGranted {
            accessibilityGranted = accessibility
        }
        let access = Permissions.clipboardAccess
        if access != clipboardAccess {
            clipboardAccess = access
            if access == .allowed {
                clipboardReadFailed = false
            }
        }
    }
}
