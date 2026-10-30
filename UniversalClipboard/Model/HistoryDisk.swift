import Foundation
import os

/// File storage for the history: `history.json` plus one folder of blobs per item.
/// Every write goes through one serial queue, so writes land in order and off the main thread.
final class HistoryDisk: Sendable {
    static let thumbnailFileName = "_thumbnail.png"

    let baseURL: URL
    private let queue = DispatchQueue(label: "com.kian.UniversalClipboard.history-disk", qos: .utility)

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    private var indexURL: URL { baseURL.appending(path: "history.json", directoryHint: .notDirectory) }
    private var itemsURL: URL { baseURL.appending(path: "items", directoryHint: .isDirectory) }

    private func folder(for id: UUID) -> URL {
        itemsURL.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    /// Loads the index, dropping entries whose files are gone and deleting folders the index no longer knows.
    func loadItems() -> [ClipItem] {
        queue.sync {
            let fileManager = FileManager.default
            var items: [ClipItem] = []
            if let data = try? Data(contentsOf: indexURL) {
                do {
                    items = try JSONDecoder().decode([ClipItem].self, from: data)
                } catch {
                    Log.storage.error("Could not read history index: \(error.localizedDescription, privacy: .public)")
                }
            }
            items = items.filter { fileManager.fileExists(atPath: folder(for: $0.id).path(percentEncoded: false)) }

            let known = Set(items.map(\.id.uuidString))
            let folders = (try? fileManager.contentsOfDirectory(at: itemsURL, includingPropertiesForKeys: nil)) ?? []
            for url in folders where !known.contains(url.lastPathComponent) {
                try? fileManager.removeItem(at: url)
            }
            return items
        }
    }

    func saveIndex(_ items: [ClipItem]) {
        queue.async { [self] in
            do {
                try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                try encoder.encode(items).write(to: indexURL, options: .atomic)
            } catch {
                Log.storage.error("Could not save history index: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func saveBlobs(_ blobs: [Blob], thumbnail: Data?, for id: UUID) {
        queue.async { [self] in
            let folder = folder(for: id)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                for blob in blobs {
                    try blob.data.write(to: folder.appending(path: blob.type, directoryHint: .notDirectory), options: .atomic)
                }
                if let thumbnail {
                    try thumbnail.write(to: folder.appending(path: Self.thumbnailFileName, directoryHint: .notDirectory), options: .atomic)
                }
            } catch {
                Log.storage.error("Could not save item: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func deleteItems(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        queue.async { [self] in
            for id in ids {
                try? FileManager.default.removeItem(at: folder(for: id))
            }
        }
    }

    func blob(_ type: String, for id: UUID) -> Data? {
        queue.sync { try? Data(contentsOf: folder(for: id).appending(path: type, directoryHint: .notDirectory)) }
    }

    func thumbnail(for id: UUID) -> Data? {
        blob(Self.thumbnailFileName, for: id)
    }

    /// Blocks until every queued write has finished.
    func flush() {
        queue.sync {}
    }
}
