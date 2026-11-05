import SwiftUI

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

                    TextField("Search clipboard history...", text: $clipboardService.searchQuery)
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
                }
            }
            .padding(.horizontal, 4)

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

            // List of clips
            if clipboardService.filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 24))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text(clipboardService.searchQuery.isEmpty ? "Copy any text or link to see it here" : "No matching clippings")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(clipboardService.filteredItems) { item in
                            clipRow(item)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(maxHeight: 110)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func clipRow(_ item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            // Badge
            Text(item.type.rawValue)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(badgeColor(for: item.type))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(badgeColor(for: item.type).opacity(0.18))
                .cornerRadius(4)

            // Content preview
            Text(item.preview)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.relativeTime)
                .font(.system(size: 9))
                .foregroundColor(Color.white.opacity(0.4))

            // Copy button
            Button(action: {
                clipboardService.copyToClipboard(item)
            }) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                    .frame(width: 22, height: 22)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: {
                clipboardService.deleteItem(id: item.id)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .cornerRadius(7)
    }

    private func badgeColor(for type: ClipboardItemType) -> Color {
        switch type {
        case .text: return .blue
        case .url: return .cyan
        case .color: return .purple
        case .code: return .orange
        }
    }
}
