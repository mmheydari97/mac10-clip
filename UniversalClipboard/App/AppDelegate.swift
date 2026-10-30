import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    let store: HistoryStore

    private let monitor = PasteboardMonitor()
    private let pasteService: PasteService
    private let panel: HistoryPanelController
    private let settingsWindow = SettingsWindowController()
    private var permissionTimer: Timer?
    private var didPromptForAccessibility = false

    override init() {
        Preferences.registerDefaults()
        store = HistoryStore(directory: Preferences.historyDirectory, limit: Preferences.historyLimit)
        pasteService = PasteService(store: store)
        panel = HistoryPanelController(store: store)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Preferences.isRunningTests else { return }

        monitor.onCapture = { [weak self] raw in self?.record(raw) }
        monitor.onUnreadable = { [weak self] in self?.state.clipboardReadFailed = true }
        pasteService.onWrite = { [weak self] in self?.monitor.skipCurrentChange() }
        panel.onPick = { [weak self] item, plainText in self?.pick(item, plainText: plainText) }
        monitor.start()

        KeyboardShortcuts.onKeyDown(for: .showHistory) { [weak self] in
            self?.panel.toggle()
        }
        startPermissionRefresh()
        Log.app.notice("Started. Accessibility: \(self.state.accessibilityGranted), clipboard access: \(String(describing: self.state.clipboardAccess), privacy: .public)")

        if !Preferences.hasOnboarded {
            Preferences.hasOnboarded = true
            showSettings()
        }
    }

    func showHistory() {
        // Let the menu that triggered this finish closing before the panel takes keyboard focus.
        Task { @MainActor in panel.show() }
    }

    func showSettings() {
        settingsWindow.show(store: store, state: state)
    }

    func requestAccessibility() {
        Permissions.requestAccessibility()
        Permissions.openAccessibilitySettings()
    }

    private func record(_ raw: RawClip) {
        state.clipboardReadFailed = false
        Task {
            let processed = await Task.detached(priority: .userInitiated) { ClipProcessor.process(raw) }.value
            if let processed {
                store.add(processed)
            }
        }
    }

    private func pick(_ item: ClipItem, plainText: Bool) {
        panel.close()
        guard pasteService.copy(item, plainText: plainText), Preferences.pasteAutomatically else { return }

        state.refresh()
        if state.accessibilityGranted {
            Task {
                // Give the previous app's window a moment to become key again.
                try? await Task.sleep(for: .milliseconds(50))
                PasteService.postPasteShortcut()
            }
        } else if !didPromptForAccessibility {
            didPromptForAccessibility = true
            Permissions.requestAccessibility()
        }
    }

    private func startPermissionRefresh() {
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.state.refresh() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }
}
