import SwiftUI

public struct FileShelfView: View {
    @ObservedObject var fileShelfService: FileShelfService
    @State private var isShelfTargeted: Bool = false

    public init(fileShelfService: FileShelfService) {
        self.fileShelfService = fileShelfService
    }

    private var isTargetedActive: Bool {
        isShelfTargeted || fileShelfService.isDropTargetActive
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

                if let status = fileShelfService.conversionStatusMessage {
                    Text(status)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                        .transition(.opacity)
                }

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
                    Image(systemName: isTargetedActive ? "arrow.down.circle.fill" : "arrow.down.doc")
                        .font(.system(size: 24))
                        .foregroundColor(isTargetedActive ? .cyan : Color.white.opacity(0.35))
                        .scaleEffect(isTargetedActive ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTargetedActive)

                    Text(isTargetedActive ? "Release to Stash in OpenHalo Shelf" : "Drag & drop files here to stash, AirDrop, or SIPS convert")
                        .font(.system(size: 11, weight: isTargetedActive ? .semibold : .regular))
                        .foregroundColor(isTargetedActive ? .cyan : Color.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, minHeight: 65)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isTargetedActive ? Color.cyan.opacity(0.08) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    isTargetedActive ? Color.cyan : Color.white.opacity(0.15),
                                    style: StrokeStyle(lineWidth: isTargetedActive ? 1.5 : 1, dash: [4])
                                )
                        )
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
        .onDrop(of: [.fileURL, .item, .data], isTargeted: $isShelfTargeted) { providers in
            Task { @MainActor in
                let urls = await FileDropResolver.resolveURLs(from: providers)
                if !urls.isEmpty {
                    fileShelfService.addFiles(urls)
                }
            }
            return true
        }
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
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
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

            if isImageFile(item.url) {
                Divider()
                Menu("Vision AI Tools") {
                    Button("Remove Background (AI)") {
                        Task {
                            if let output = try? await VisionProcessingService.removeBackground(from: item.url) {
                                fileShelfService.addFiles([output])
                            }
                        }
                    }
                    Button("Extract Text (OCR)") {
                        Task {
                            if let text = try? await VisionProcessingService.extractText(from: item.url), !text.isEmpty {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                            }
                        }
                    }
                }

                Menu("SIPS Convert Image") {
                    Button("Convert to PNG") {
                        Task { await fileShelfService.convertItem(item, to: .png) }
                    }
                    Button("Convert to JPEG") {
                        Task { await fileShelfService.convertItem(item, to: .jpeg) }
                    }
                    Button("Convert to WebP") {
                        Task { await fileShelfService.convertItem(item, to: .webp) }
                    }
                    Button("Convert to HEIC") {
                        Task { await fileShelfService.convertItem(item, to: .heic) }
                    }
                    Button("Convert to TIFF") {
                        Task { await fileShelfService.convertItem(item, to: .tiff) }
                    }
                }

                Menu("SIPS Resize") {
                    Button("Downscale to 1920px") {
                        Task { await fileShelfService.downscaleItem(item, maxDimension: 1920) }
                    }
                    Button("Downscale to 1280px") {
                        Task { await fileShelfService.downscaleItem(item, maxDimension: 1280) }
                    }
                    Button("Downscale to 800px") {
                        Task { await fileShelfService.downscaleItem(item, maxDimension: 800) }
                    }
                }
            }

            Divider()
            Button("Remove from Shelf") {
                fileShelfService.removeItem(id: item.id)
            }
        }
    }

    private func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "webp", "heic", "tiff", "gif", "bmp"].contains(ext)
    }
}
