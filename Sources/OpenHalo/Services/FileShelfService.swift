import Foundation
import AppKit

@MainActor
public final class FileShelfService: ObservableObject {
    @Published public var items: [ShelfItem] = []
    @Published public var isDropTargetActive: Bool = false
    @Published public var conversionStatusMessage: String? = nil

    private let persistenceKey = "OpenHalo.FileShelf.StagedPaths"

    public init() {
        restoreShelfState()
    }

    public func addFiles(_ urls: [URL]) {
        for url in urls {
            // Check if already in shelf
            if !items.contains(where: { $0.url.path == url.path }) {
                let item = ShelfItem(url: url)
                items.insert(item, at: 0)
            }
        }
        if !urls.isEmpty {
            SoundEffectManager.playDropStash()
            saveShelfState()
        }
    }

    public func removeItem(id: UUID) {
        items.removeAll(where: { $0.id == id })
        saveShelfState()
    }

    public func clearAll() {
        items.removeAll()
        saveShelfState()
    }

    public func openFile(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    public func revealInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    // MARK: - Reboot Persistence

    private func saveShelfState() {
        let paths = items.map { $0.url.path }
        UserDefaults.standard.set(paths, forKey: persistenceKey)
    }

    private func restoreShelfState() {
        guard let paths = UserDefaults.standard.stringArray(forKey: persistenceKey) else { return }
        var restored: [ShelfItem] = []
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                restored.append(ShelfItem(url: url))
            }
        }
        self.items = restored
    }

    // MARK: - Native AirDrop & Sharing Features

    public func airDropItem(_ item: ShelfItem) {
        if let airDropService = NSSharingService(named: .sendViaAirDrop) {
            if airDropService.canPerform(withItems: [item.url]) {
                airDropService.perform(withItems: [item.url])
            }
        }
    }

    public func airDropAll() {
        let urls = items.map { $0.url }
        guard !urls.isEmpty else { return }
        if let airDropService = NSSharingService(named: .sendViaAirDrop) {
            if airDropService.canPerform(withItems: urls) {
                airDropService.perform(withItems: urls)
            }
        }
    }

    public func shareItem(_ item: ShelfItem, from view: NSView) {
        let picker = NSSharingServicePicker(items: [item.url])
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    // MARK: - SIPS Quick Image Conversion

    public func convertItem(_ item: ShelfItem, to format: SIPSImageFormat) async {
        do {
            conversionStatusMessage = "Converting to \(format.displayName)..."
            let targetURL = try await SIPSConversionService.shared.convert(inputURL: item.url, to: format)
            addFiles([targetURL])
            conversionStatusMessage = "Converted: \(targetURL.lastPathComponent)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.conversionStatusMessage = nil
            }
        } catch {
            conversionStatusMessage = "Conversion failed: \(error.localizedDescription)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.conversionStatusMessage = nil
            }
        }
    }

    public func downscaleItem(_ item: ShelfItem, maxDimension: Int) async {
        do {
            conversionStatusMessage = "Rescaling to \(maxDimension)px..."
            let targetURL = try await SIPSConversionService.shared.downscale(inputURL: item.url, maxDimension: maxDimension)
            addFiles([targetURL])
            conversionStatusMessage = "Rescaled: \(targetURL.lastPathComponent)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.conversionStatusMessage = nil
            }
        } catch {
            conversionStatusMessage = "Rescaling failed: \(error.localizedDescription)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.conversionStatusMessage = nil
            }
        }
    }
}
