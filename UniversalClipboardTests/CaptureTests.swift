import AppKit
import Testing
@testable import UniversalClipboard

/// Runs capture rules against a private pasteboard, so the real clipboard is never touched.
@MainActor
struct CaptureTests {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("UniversalClipboardTests-\(UUID().uuidString)"))

    private func write(_ representations: [NSPasteboard.PasteboardType: Data]) {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        for (type, data) in representations {
            item.setData(data, forType: type)
        }
        pasteboard.writeObjects([item])
    }

    private func capturedClip() -> RawClip? {
        if case .clip(let raw) = ClipCapture.read(from: pasteboard) {
            return raw
        }
        return nil
    }

    private static func tiffImage(width: Int, height: Int) -> Data {
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            NSColor.systemTeal.setFill()
            rect.fill()
            return true
        }
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return rep.tiffRepresentation!
    }

    @Test func plainTextIsCapturedAsLocal() throws {
        write([.string: Data("hello world".utf8)])
        let raw = try #require(capturedClip())
        #expect(raw.text == "hello world")
        #expect(raw.isRemote == false)
    }

    @Test func richTextIsKeptForPasting() throws {
        let rtf = Data(#"{\rtf1\ansi {\b bold}}"#.utf8)
        pasteboard.clearContents()
        pasteboard.declareTypes([.rtf, .string], owner: nil)
        pasteboard.setData(rtf, forType: .rtf)
        pasteboard.setString("bold", forType: .string)

        let raw = try #require(capturedClip())
        let clip = try #require(ClipProcessor.process(raw))
        #expect(clip.kind == .text)
        #expect(clip.blobs.map(\.type) == ["public.rtf", "public.utf8-plain-text"])
    }

    @Test func passwordManagerItemsAreSkipped() {
        write([.string: Data("hunter2".utf8), .concealed: Data()])
        #expect(capturedClip() == nil)
    }

    @Test func universalClipboardItemsAreTagged() throws {
        write([.string: Data("from my other Mac".utf8), .remoteClipboard: Data()])
        let raw = try #require(capturedClip())
        #expect(raw.isRemote)
    }

    @Test func finderFileCopiesAreIgnored() {
        write([.fileURL: Data("file:///tmp/a.png".utf8), .string: Data("a.png".utf8)])
        #expect(capturedClip() == nil)
    }

    @Test func whitespaceOnlyTextIsIgnored() {
        write([.string: Data(" \n\t ".utf8)])
        #expect(capturedClip() == nil)
    }

    @Test func tiffImageIsConvertedToPNG() throws {
        pasteboard.clearContents()
        pasteboard.setData(Self.tiffImage(width: 40, height: 30), forType: .tiff)

        let raw = try #require(capturedClip())
        let clip = try #require(ClipProcessor.process(raw))
        #expect(clip.kind == .image)
        #expect(clip.blobs.map(\.type) == ["public.png"])
        #expect(clip.imageWidth == 40)
        #expect(clip.imageHeight == 30)
        #expect(clip.thumbnail != nil)
        #expect(NSBitmapImageRep(data: clip.blobs[0].data) != nil)
    }

    @Test func imageListedBeforeTextIsAnImage() throws {
        pasteboard.clearContents()
        pasteboard.declareTypes([.tiff, .string], owner: nil)
        pasteboard.setData(Self.tiffImage(width: 8, height: 8), forType: .tiff)
        pasteboard.setString("https://example.com/cat.png", forType: .string)

        let raw = try #require(capturedClip())
        #expect(raw.imageData != nil)
        #expect(raw.text == nil)
    }

    @Test func textListedBeforeImageIsText() throws {
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, .tiff], owner: nil)
        pasteboard.setString("A1\tB1", forType: .string)
        pasteboard.setData(Self.tiffImage(width: 8, height: 8), forType: .tiff)

        let raw = try #require(capturedClip())
        #expect(raw.text == "A1\tB1")
    }

    @Test func previewCollapsesWhitespace() {
        #expect(ClipProcessor.preview(for: "  line one\n\n   line two\t end ") == "line one line two end")
    }
}

@MainActor
struct PanelPlacementTests {
    let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
    let size = NSSize(width: 380, height: 300)

    @Test func opensBelowAndRightOfThePointer() {
        let frame = HistoryPanelController.frame(for: size, at: NSPoint(x: 100, y: 700), in: screen)
        #expect(frame.origin == NSPoint(x: 100, y: 400))
    }

    @Test func flipsAboveThePointerNearTheBottom() {
        let frame = HistoryPanelController.frame(for: size, at: NSPoint(x: 100, y: 50), in: screen)
        #expect(frame.origin == NSPoint(x: 100, y: 50))
    }

    @Test func staysOnScreenNearTheRightEdge() {
        let frame = HistoryPanelController.frame(for: size, at: NSPoint(x: 950, y: 700), in: screen)
        #expect(frame.maxX == 1000)
    }
}
