import AppKit
import SwiftUI

struct HistoryListView: View {
    let store: HistoryStore
    let model: HistoryListModel
    let onPick: (ClipItem, Bool) -> Void

    @AppStorage(Preferences.Key.pasteAutomatically) private var pasteAutomatically = true

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                Text("Nothing copied yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
            Divider()
            footer
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: HistoryMetrics.rowSpacing) {
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                        HistoryRow(
                            item: item,
                            index: index,
                            isSelected: index == model.selection,
                            thumbnail: item.kind == .image ? store.thumbnail(for: item) : nil
                        )
                        .id(item.id)
                        .contentShape(.rect)
                        .onTapGesture {
                            onPick(item, NSEvent.modifierFlags.contains(.shift))
                        }
                        .onHover { hovering in
                            if hovering {
                                model.selection = index
                            }
                        }
                    }
                }
                .padding(HistoryMetrics.padding)
            }
            .onChange(of: model.selection) { _, selection in
                guard store.items.indices.contains(selection) else { return }
                proxy.scrollTo(store.items[selection].id)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text("↩ \(pasteAutomatically ? "paste" : "copy")")
            Text("⇧↩ plain text")
            Text("1–9 pick")
            Spacer()
            Text("esc close")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: HistoryMetrics.footerHeight)
    }
}

private struct HistoryRow: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 8) {
            Text(index < 9 ? "\(index + 1)" : "")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                .frame(width: 12, alignment: .trailing)
            content
            Spacer(minLength: 4)
            if item.source == .otherDevice {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                    .help("Copied on another device (Universal Clipboard)")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: HistoryMetrics.rowHeight(for: item.kind))
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(isSelected ? Color.accentColor : Color.clear, in: .rect(cornerRadius: 6))
        .help("Copied \(item.lastCopiedAt.formatted(.relative(presentation: .named)))")
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(item.preview)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 64, maxHeight: HistoryMetrics.imageRowHeight - 10)
                    .clipShape(.rect(cornerRadius: 3))
            }
            Text(imageLabel)
                .font(.system(size: 13))
                .lineLimit(1)
        }
    }

    private var imageLabel: String {
        guard let width = item.imageWidth, let height = item.imageHeight else { return "Image" }
        return "Image  \(width) × \(height)"
    }
}
