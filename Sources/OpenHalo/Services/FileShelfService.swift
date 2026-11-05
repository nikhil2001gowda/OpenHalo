import Foundation
import AppKit

@MainActor
public final class FileShelfService: ObservableObject {
    @Published public var items: [ShelfItem] = []
    @Published public var isDropTargetActive: Bool = false

    public init() {}

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
        }
    }

    public func removeItem(id: UUID) {
        items.removeAll(where: { $0.id == id })
    }

    public func clearAll() {
        items.removeAll()
    }

    public func openFile(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    public func revealInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
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
}
