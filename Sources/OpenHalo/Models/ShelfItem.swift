import Foundation
import AppKit

public struct ShelfItem: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let fileSize: String
    public let dateAdded: Date
    public let isDirectory: Bool

    public init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.dateAdded = Date()

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            self.fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        } else {
            self.fileSize = isDir.boolValue ? "Folder" : "Unknown size"
        }
    }

    public static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool {
        lhs.id == rhs.id
    }
}

