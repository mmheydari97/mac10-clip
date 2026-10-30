import AppKit
import Observation

/// The clipboard history, newest first, capped at `limit` items and persisted with `HistoryDisk`.
@MainActor
@Observable
final class HistoryStore {
    private(set) var items: [ClipItem]
    private(set) var limit: Int

    @ObservationIgnored private let disk: HistoryDisk
    @ObservationIgnored private var thumbnailCache: [UUID: NSImage] = [:]

    init(directory: URL, limit: Int) {
        disk = HistoryDisk(baseURL: directory)
        self.limit = max(1, limit)
        items = disk.loadItems()
        if !trim().isEmpty {
            disk.saveIndex(items)
        }
    }

    /// Adds a captured clip. Content already in the history moves to the top instead of being stored twice.
    func add(_ clip: ProcessedClip) {
        if let existing = items.first(where: { $0.contentHash == clip.contentHash }), existing.lastCopiedAt > clip.copiedAt {
            return
        }
        let duplicates = items.filter { $0.contentHash == clip.contentHash }.map(\.id)
        items.removeAll { $0.contentHash == clip.contentHash }

        let item = ClipItem(
            id: UUID(),
            lastCopiedAt: clip.copiedAt,
            source: clip.isRemote ? .otherDevice : .thisMac,
            kind: clip.kind,
            preview: clip.preview,
            imageWidth: clip.imageWidth,
            imageHeight: clip.imageHeight,
            contentHash: clip.contentHash,
            storedTypes: clip.blobs.map(\.type)
        )
        // Clips are processed off the main thread, so a slow one can finish after a newer one.
        let index = items.firstIndex { $0.lastCopiedAt < item.lastCopiedAt } ?? items.endIndex
        items.insert(item, at: index)
        disk.saveBlobs(clip.blobs, thumbnail: clip.thumbnail, for: item.id)

        forget(duplicates + trim())
        disk.saveIndex(items)
    }

    func moveToTop(_ id: UUID, at date: Date = .now) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.lastCopiedAt = date
        items.insert(item, at: 0)
        disk.saveIndex(items)
    }

    func setLimit(_ newLimit: Int) {
        limit = max(1, newLimit)
        let removed = trim()
        guard !removed.isEmpty else { return }
        forget(removed)
        disk.saveIndex(items)
    }

    func clear() {
        let ids = items.map(\.id)
        items.removeAll()
        forget(ids)
        disk.saveIndex(items)
    }

    func data(for item: ClipItem, type: String) -> Data? {
        disk.blob(type, for: item.id)
    }

    func thumbnail(for item: ClipItem) -> NSImage? {
        if let cached = thumbnailCache[item.id] {
            return cached
        }
        guard let data = disk.thumbnail(for: item.id), let image = NSImage(data: data) else { return nil }
        thumbnailCache[item.id] = image
        return image
    }

    /// Waits for pending disk writes; used by tests.
    func flush() {
        disk.flush()
    }

    /// Drops items past the limit and returns their IDs.
    private func trim() -> [UUID] {
        guard items.count > limit else { return [] }
        let removed = items[limit...].map(\.id)
        items.removeSubrange(limit...)
        return removed
    }

    private func forget(_ ids: [UUID]) {
        for id in ids {
            thumbnailCache[id] = nil
        }
        disk.deleteItems(ids)
    }
}
