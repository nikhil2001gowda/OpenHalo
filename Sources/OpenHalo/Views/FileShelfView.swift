import SwiftUI

public struct FileShelfView: View {
    @ObservedObject var fileShelfService: FileShelfService

    public init(fileShelfService: FileShelfService) {
        self.fileShelfService = fileShelfService
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)

                    Text("File Shelf Stash (\(fileShelfService.items.count))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                if !fileShelfService.items.isEmpty {
                    HStack(spacing: 6) {
                        // AirDrop All
                        Button(action: { fileShelfService.airDropAll() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "airdrop")
                                    .font(.system(size: 10, weight: .bold))
                                Text("AirDrop All")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.cyan.opacity(0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { fileShelfService.clearAll() }) {
                            Text("Clear")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)

            // Content: Empty or List
            if fileShelfService.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 24))
                        .foregroundColor(Color.white.opacity(0.35))

                    Text("Drag & drop files here to stash or AirDrop")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, minHeight: 65)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(fileShelfService.items) { item in
                            shelfItemChip(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 68)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func shelfItemChip(_ item: ShelfItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 18))
                .foregroundColor(item.isDirectory ? .cyan : .blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 85, alignment: .leading)

                Text(item.fileSize)
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.5))
            }

            // AirDrop Action
            Button(action: { fileShelfService.airDropItem(item) }) {
                Image(systemName: "airdrop")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyan)
            }
            .buttonStyle(.plain)

            Button(action: { fileShelfService.removeItem(id: item.id) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .onTapGesture(count: 2) {
            fileShelfService.openFile(item)
        }
        .contextMenu {
            Button("AirDrop File") {
                fileShelfService.airDropItem(item)
            }
            Button("Open File") {
                fileShelfService.openFile(item)
            }
            Button("Reveal in Finder") {
                fileShelfService.revealInFinder(item)
            }
            Divider()
            Button("Remove from Shelf") {
                fileShelfService.removeItem(id: item.id)
            }
        }
    }
}
