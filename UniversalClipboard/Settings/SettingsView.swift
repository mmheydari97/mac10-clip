import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let store: HistoryStore
    let state: AppState

    @AppStorage(Preferences.Key.historyLimit) private var historyLimit = Preferences.defaultHistoryLimit
    @AppStorage(Preferences.Key.pasteAutomatically) private var pasteAutomatically = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    // Plain stacks rather than a grouped Form: a Form scrolls, so it has no natural height, and the
    // window sizing itself to it loops until AppKit throws.
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 12) {
                    GridRow {
                        Text("Show history:")
                            .gridColumnAlignment(.trailing)
                        KeyboardShortcuts.Recorder(for: .showHistory)
                    }
                    GridRow {
                        Text("Keep the last:")
                        Picker("Keep the last:", selection: $historyLimit) {
                            ForEach(Preferences.historyLimitOptions, id: \.self) { limit in
                                Text("\(limit) items").tag(limit)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    GridRow {
                        Text("")
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Paste automatically after choosing an item", isOn: $pasteAutomatically)
                            Toggle("Launch at login", isOn: $launchAtLogin)
                            Text("Hold Shift while choosing to paste as plain text.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Permissions") {
                VStack(spacing: 10) {
                    PermissionRow(
                        title: "Accessibility",
                        detail: "Lets the app paste into the app you were using.",
                        isGranted: state.accessibilityGranted
                    ) {
                        Permissions.requestAccessibility()
                        Permissions.openAccessibilitySettings()
                    }
                    Divider()
                    PermissionRow(
                        title: "Clipboard access",
                        detail: "In Paste from Other Apps, allow Universal Clipboard so it can record what you copy.",
                        isGranted: !state.hasClipboardAccessProblem,
                        action: Permissions.openClipboardSettings
                    )
                }
                .padding(8)
            }

            GroupBox("Other devices") {
                Text("Copies from your other Macs, iPhone or iPad show up here when Handoff is on, the devices use the same Apple ID and are near each other. Install this app on each Mac to keep a history there too.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: historyLimit) { _, limit in
            store.setLimit(limit)
        }
        .onChange(of: launchAtLogin) { _, enabled in
            LaunchAtLogin.set(enabled)
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isGranted ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if !isGranted {
                Button("Open System Settings", action: action)
            }
        }
    }
}

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        [.enabled, .requiresApproval].contains(SMAppService.mainApp.status)
    }

    static func set(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(store: HistoryStore, state: AppState) {
        let window = window ?? makeWindow(store: store, state: state)
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(store: HistoryStore, state: AppState) -> NSWindow {
        let controller = NSHostingController(rootView: SettingsView(store: store, state: state))
        controller.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: controller)
        window.title = "Universal Clipboard Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
