import Foundation

/// One entry in the clipboard history. The copied data itself lives on disk under `items/<id>/`.
struct ClipItem: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case text, image
    }

    enum Source: String, Codable, Sendable {
        case thisMac
        /// Handed over by Universal Clipboard from another Mac, iPhone or iPad.
        case otherDevice
    }

    let id: UUID
    var lastCopiedAt: Date
    var source: Source
    let kind: Kind
    /// Single-line preview for text items; empty for images.
    let preview: String
    let imageWidth: Int?
    let imageHeight: Int?
    /// SHA-256 of the plain text (text items) or of the stored image bytes (image items).
    let contentHash: String
    /// Pasteboard types saved for this item, in the order they are written back.
    let storedTypes: [String]
}
