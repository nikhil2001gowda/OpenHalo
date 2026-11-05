import SwiftUI
import AppKit

public struct ClipboardExpandedView: View {
    @ObservedObject var clipboardService: ClipboardHistoryService

    public init(clipboardService: ClipboardHistoryService) {
        self.clipboardService = clipboardService
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header & Search
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))

                    TextField("Search text, links, or screenshots...", text: $clipboardService.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .onTapGesture {
                            IslandCoordinator.shared.setKeyboardFocus(true)
                        }

                    if !clipboardService.searchQuery.isEmpty {
                        Button(action: { clipboardService.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)

                if !clipboardService.items.isEmpty {
                    Button(action: { clipboardService.clearAll() }) {
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Clear non-pinned items")
                }
            }
            .padding(.horizontal, 4)

            // Category Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(ClipboardItemType.allCases, id: \.self) { filterType in
                        let isSelected = clipboardService.selectedFilter == filterType
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                clipboardService.selectedFilter = filterType
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: iconForFilter(filterType))
                                    .font(.system(size: 9))
                                Text(filterType.rawValue)
                                    .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
                            }
                            .foregroundColor(isSelected ? .black : Color.white.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(isSelected ? Color.white : Color.white.opacity(0.08))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Toast Alert
            if let toast = clipboardService.lastCopiedToast {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.vertical, 2)
                .transition(.opacity)
            }

            // Content List
            if clipboardService.filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 22))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text(clipboardService.searchQuery.isEmpty ? "Copy images, screenshots (Cmd+Ctrl+Shift+4), or text" : "No matching clippings")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, minHeight: 65)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(clipboardService.filteredItems) { item in
                            clipCard(item)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(maxHeight: 115)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func clipCard(_ item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            // Pin Indicator
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.yellow)
            }

            // Image Preview or Icon/Swatch Badge
            if item.type == .image, let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
            } else if item.type == .color {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: item.content) ?? .gray)
                        .frame(width: 12, height: 12)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                    Text("HEX")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
            } else {
                Text(item.type.rawValue)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(badgeColor(item.type))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(badgeColor(item.type).opacity(0.15))
                    .cornerRadius(4)
            }

            // Content Preview
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.system(size: 11, weight: .medium, design: (item.type == .code || item.type == .color) ? .monospaced : .default))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(item.relativeTime)
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.45))
            }

            Spacer()

            // Actions: OCR from image, Pin, Copy, Delete
            HStack(spacing: 6) {
                // OCR Button for Images
                if item.type == .image, let data = item.imageData {
                    Button(action: {
                        Task {
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
                            try? data.write(to: tempURL)
                            if let text = try? await VisionProcessingService.extractText(from: tempURL), !text.isEmpty {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                                clipboardService.copyToClipboard(ClipboardItem(content: text))
                            }
                            try? FileManager.default.removeItem(at: tempURL)
                        }
                    }) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)
                    .help("Extract text from image (OCR)")
                }

                // Pin Button
                Button(action: {
                    clipboardService.togglePin(id: item.id)
                }) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10))
                        .foregroundColor(item.isPinned ? .yellow : Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "Unpin item" : "Pin item to top")

                // Copy Action Button
                Button(action: {
                    clipboardService.copyToClipboard(item)
                }) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")

                // Delete Action Button
                Button(action: {
                    clipboardService.deleteItem(id: item.id)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .help("Delete clipping")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(item.isPinned ? 0.12 : 0.05))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            clipboardService.copyToClipboard(item)
        }
    }

    private func iconForFilter(_ type: ClipboardItemType) -> String {
        switch type {
        case .all: return "square.grid.2x2"
        case .image: return "photo.fill"
        case .text: return "text.alignleft"
        case .url: return "link"
        case .color: return "paintpalette.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }

    private func badgeColor(_ type: ClipboardItemType) -> Color {
        switch type {
        case .all: return .white
        case .image: return .purple
        case .text: return .blue
        case .url: return .green
        case .color: return .orange
        case .code: return .cyan
        }
    }
}

// Hex Color Extension
extension Color {
    init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }

        guard cleanHex.count == 6 || cleanHex.count == 8 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: cleanHex).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
