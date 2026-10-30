import AppKit
import Carbon.HIToolbox
import SwiftUI

enum HistoryMetrics {
    static let width: CGFloat = 380
    static let textRowHeight: CGFloat = 28
    static let imageRowHeight: CGFloat = 52
    static let rowSpacing: CGFloat = 2
    static let padding: CGFloat = 6
    static let footerHeight: CGFloat = 26
    static let maxListHeight: CGFloat = 420
    static let emptyHeight: CGFloat = 80
    static let cornerRadius: CGFloat = 10

    static func rowHeight(for kind: ClipItem.Kind) -> CGFloat {
        kind == .image ? imageRowHeight : textRowHeight
    }
}

/// Selection state shared by the panel controller (keyboard) and the list view (mouse).
@MainActor
@Observable
final class HistoryListModel {
    var selection = 0
}

/// Borderless panel that takes keyboard focus without activating the app,
/// so the app you were typing in stays frontmost and receives the paste.
final class HistoryPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: HistoryMetrics.width, height: 300),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class HistoryPanelController {
    /// Called with the chosen item and whether to paste it as plain text.
    var onPick: ((ClipItem, Bool) -> Void)?

    private let store: HistoryStore
    private let model = HistoryListModel()
    private var panel: HistoryPanel?
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    private static let digitKeys: [Int: Int] = [
        kVK_ANSI_1: 1, kVK_ANSI_2: 2, kVK_ANSI_3: 3, kVK_ANSI_4: 4, kVK_ANSI_5: 5,
        kVK_ANSI_6: 6, kVK_ANSI_7: 7, kVK_ANSI_8: 8, kVK_ANSI_9: 9,
        kVK_ANSI_Keypad1: 1, kVK_ANSI_Keypad2: 2, kVK_ANSI_Keypad3: 3, kVK_ANSI_Keypad4: 4, kVK_ANSI_Keypad5: 5,
        kVK_ANSI_Keypad6: 6, kVK_ANSI_Keypad7: 7, kVK_ANSI_Keypad8: 8, kVK_ANSI_Keypad9: 9,
    ]

    init(store: HistoryStore) {
        self.store = store
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func toggle() {
        isVisible ? close() : show()
    }

    func show() {
        model.selection = 0
        let panel = panel ?? makePanel()
        self.panel = panel

        let size = NSSize(width: HistoryMetrics.width, height: preferredHeight())
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        panel.setFrame(Self.frame(for: size, at: mouse, in: visibleFrame), display: false)
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.invalidateShadow()
        startMonitoringKeys(for: panel)
    }

    func close() {
        stopMonitoringKeys()
        panel?.orderOut(nil)
    }

    /// Puts the panel's top-left corner at `point`, flips it above the point when there is no room
    /// below, and keeps it inside `visibleFrame`.
    static func frame(for size: NSSize, at point: NSPoint, in visibleFrame: NSRect) -> NSRect {
        var origin = NSPoint(x: point.x, y: point.y - size.height)
        if origin.y < visibleFrame.minY {
            origin.y = point.y
        }
        origin.x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width)
        origin.y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        return NSRect(origin: origin, size: size)
    }

    private func preferredHeight() -> CGFloat {
        guard !store.items.isEmpty else {
            return HistoryMetrics.emptyHeight + HistoryMetrics.footerHeight
        }
        let rows = store.items.reduce(-HistoryMetrics.rowSpacing) {
            $0 + HistoryMetrics.rowHeight(for: $1.kind) + HistoryMetrics.rowSpacing
        }
        return min(rows + HistoryMetrics.padding * 2, HistoryMetrics.maxListHeight) + HistoryMetrics.footerHeight
    }

    private func makePanel() -> HistoryPanel {
        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        // Keep the vibrant look even though the app never becomes active.
        background.state = .active
        background.maskImage = Self.roundedMask(radius: HistoryMetrics.cornerRadius)

        let list = HistoryListView(store: store, model: model) { [weak self] item, plainText in
            self?.onPick?(item, plainText)
        }
        let hostingView = NSHostingView(rootView: list)
        hostingView.sizingOptions = []
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: background.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        return HistoryPanel(contentView: background)
    }

    private func startMonitoringKeys(for panel: NSPanel) {
        stopMonitoringKeys()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = Int(event.keyCode)
            let shift = event.modifierFlags.contains(.shift)
            MainActor.assumeIsolated { self?.handleKey(keyCode, shift: shift) }
            // Swallow every key while the panel is open so nothing beeps or leaks to the app.
            return nil
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func stopMonitoringKeys() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }

    private func handleKey(_ keyCode: Int, shift: Bool) {
        switch keyCode {
        case kVK_Escape:
            close()
        case kVK_UpArrow:
            model.selection = max(model.selection - 1, 0)
        case kVK_DownArrow:
            model.selection = min(model.selection + 1, max(store.items.count - 1, 0))
        case kVK_Return, kVK_ANSI_KeypadEnter:
            pick(at: model.selection, plainText: shift)
        default:
            if let digit = Self.digitKeys[keyCode] {
                pick(at: digit - 1, plainText: shift)
            }
        }
    }

    private func pick(at index: Int, plainText: Bool) {
        guard store.items.indices.contains(index) else { return }
        onPick?(store.items[index], plainText)
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
