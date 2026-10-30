import Foundation
import Testing
@testable import UniversalClipboard

@MainActor
final class HistoryStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "UniversalClipboardTests-\(UUID().uuidString)")

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Runs `body` with a fresh store and waits for its disk writes, so `deinit` never races them.
    private func withStore(limit: Int = 10, _ body: (HistoryStore) throws -> Void) rethrows {
        let store = HistoryStore(directory: directory, limit: limit)
        defer { store.flush() }
        try body(store)
    }

    private func textClip(_ text: String, at date: Date = .now, remote: Bool = false) -> ProcessedClip {
        ClipProcessor.process(RawClip(copiedAt: date, isRemote: remote, text: text))!
    }

    @Test func newestItemComesFirst() {
        withStore { store in
            store.add(textClip("first", at: .now.addingTimeInterval(-10)))
            store.add(textClip("second"))
            #expect(store.items.map(\.preview) == ["second", "first"])
        }
    }

    @Test func duplicateMovesToTopInsteadOfBeingStoredTwice() {
        withStore { store in
            store.add(textClip("a", at: .now.addingTimeInterval(-20)))
            store.add(textClip("b", at: .now.addingTimeInterval(-10)))
            store.add(textClip("a", remote: true))
            #expect(store.items.map(\.preview) == ["a", "b"])
            #expect(store.items.first?.source == .otherDevice)
        }
    }

    @Test func lateClipIsSortedByCopyTime() {
        withStore { store in
            store.add(textClip("newer"))
            store.add(textClip("older", at: .now.addingTimeInterval(-60)))
            #expect(store.items.map(\.preview) == ["newer", "older"])
        }
    }

    @Test func trimsToLimitAndDeletesFiles() throws {
        try withStore(limit: 3) { store in
            for index in 0..<5 {
                store.add(textClip("item \(index)", at: .now.addingTimeInterval(Double(index))))
            }
            store.flush()
            #expect(store.items.map(\.preview) == ["item 4", "item 3", "item 2"])
            let itemsPath = directory.appending(path: "items").path(percentEncoded: false)
            let folders = try FileManager.default.contentsOfDirectory(atPath: itemsPath)
            #expect(folders.count == 3)
        }
    }

    @Test func loweringTheLimitTrimsImmediately() {
        withStore { store in
            for index in 0..<5 {
                store.add(textClip("item \(index)", at: .now.addingTimeInterval(Double(index))))
            }
            store.setLimit(2)
            #expect(store.items.map(\.preview) == ["item 4", "item 3"])
        }
    }

    @Test func historySurvivesRelaunch() throws {
        withStore { store in
            store.add(textClip("keep me"))
        }
        try withStore { reloaded in
            let item = try #require(reloaded.items.first)
            #expect(reloaded.items.count == 1)
            #expect(item.preview == "keep me")
            #expect(reloaded.data(for: item, type: "public.utf8-plain-text") == Data("keep me".utf8))
        }
    }

    @Test func clearRemovesEverything() {
        withStore { store in
            store.add(textClip("x"))
            store.add(textClip("y"))
            store.clear()
            #expect(store.items.isEmpty)
        }
        withStore { reloaded in
            #expect(reloaded.items.isEmpty)
        }
    }

    @Test func moveToTopReordersWithoutDuplicating() throws {
        try withStore { store in
            store.add(textClip("a", at: .now.addingTimeInterval(-10)))
            store.add(textClip("b"))
            let a = try #require(store.items.last)
            store.moveToTop(a.id)
            #expect(store.items.map(\.preview) == ["a", "b"])
        }
    }
}
