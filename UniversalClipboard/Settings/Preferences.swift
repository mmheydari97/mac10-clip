import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showHistory = Self("showHistory", default: .init(.v, modifiers: [.command, .shift]))
}

/// UserDefaults-backed settings. Any key can be overridden at launch, e.g. `-historyDirectory /tmp/h`.
enum Preferences {
    static let historyLimitOptions = [10, 20, 50, 100]
    static let defaultHistoryLimit = 20

    enum Key {
        static let historyLimit = "historyLimit"
        static let pasteAutomatically = "pasteAutomatically"
        static let hasOnboarded = "hasOnboarded"
        static let historyDirectory = "historyDirectory"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.historyLimit: defaultHistoryLimit,
            Key.pasteAutomatically: true,
        ])
    }

    static var historyLimit: Int {
        let value = UserDefaults.standard.integer(forKey: Key.historyLimit)
        return value > 0 ? value : defaultHistoryLimit
    }

    static var pasteAutomatically: Bool {
        UserDefaults.standard.bool(forKey: Key.pasteAutomatically)
    }

    static var hasOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: Key.hasOnboarded) }
        set { UserDefaults.standard.set(newValue, forKey: Key.hasOnboarded) }
    }

    static var historyDirectory: URL {
        if let path = UserDefaults.standard.string(forKey: Key.historyDirectory) {
            return URL(filePath: path, directoryHint: .isDirectory)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appending(path: Bundle.main.bundleIdentifier ?? "com.kian.UniversalClipboard", directoryHint: .isDirectory)
    }

    /// True when the app is hosting unit tests; it then skips clipboard monitoring and the hotkey.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil
    }
}
