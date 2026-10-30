import os

/// View with: log show --last 1h --predicate 'subsystem == "com.kian.UniversalClipboard"'
enum Log {
    static let app = Logger(subsystem: "com.kian.UniversalClipboard", category: "app")
    static let capture = Logger(subsystem: "com.kian.UniversalClipboard", category: "capture")
    static let storage = Logger(subsystem: "com.kian.UniversalClipboard", category: "storage")
}
