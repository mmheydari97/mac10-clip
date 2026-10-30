import KeyboardShortcuts
import SwiftUI

@main
struct UniversalClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Universal Clipboard", systemImage: "list.clipboard") {
            StatusMenu(app: appDelegate, state: appDelegate.state, store: appDelegate.store)
        }
    }
}

private struct StatusMenu: View {
    let app: AppDelegate
    let state: AppState
    let store: HistoryStore

    @AppStorage(Preferences.Key.pasteAutomatically) private var pasteAutomatically = true

    var body: some View {
        Button("Show History") { app.showHistory() }
            .globalKeyboardShortcut(.showHistory)

        if pasteAutomatically && !state.accessibilityGranted {
            Button("⚠️ Allow Accessibility to Paste Automatically…") { app.requestAccessibility() }
        }
        if state.hasClipboardAccessProblem {
            Button("⚠️ Allow Clipboard Access…") { Permissions.openClipboardSettings() }
        }

        Divider()
        Button("Clear History") { store.clear() }
            .disabled(store.items.isEmpty)
        Divider()
        Button("Settings…") { app.showSettings() }
            .keyboardShortcut(",")
        Button("Quit Universal Clipboard") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
