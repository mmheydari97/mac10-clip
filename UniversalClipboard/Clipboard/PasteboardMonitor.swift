import AppKit

/// Watches the clipboard for new copies. macOS has no change notification, so it polls `changeCount`.
@MainActor
final class PasteboardMonitor {
    static let pollInterval: TimeInterval = 0.5

    var onCapture: ((RawClip) -> Void)?
    var onUnreadable: (() -> Void)?

    private let pasteboard: NSPasteboard
    private var lastChangeCount = -1
    private var timer: Timer?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.1
        // .common keeps it firing while menus are open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        poll()
    }

    /// Call right after the app writes to the clipboard, so that write isn't recorded as a new copy.
    func skipCurrentChange() {
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        switch ClipCapture.read(from: pasteboard) {
        case .clip(let raw):
            onCapture?(raw)
        case .unreadable:
            onUnreadable?()
        case .ignored:
            break
        }
    }
}
