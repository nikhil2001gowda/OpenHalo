import Foundation

public enum ClipboardItemType: String, Sendable, CaseIterable {
    case text = "Text"
    case url = "Link"
    case color = "Color"
    case code = "Code"
}

public struct ClipboardItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let content: String
    public let timestamp: Date
    public let type: ClipboardItemType
    public let characterCount: Int

    public init(id: UUID = UUID(), content: String, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.characterCount = content.count

        // Automatic content classification
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            self.type = .url
        } else if trimmed.hasPrefix("#") && (trimmed.count == 4 || trimmed.count == 7 || trimmed.count == 9) {
            self.type = .color
        } else if trimmed.contains("func ") || trimmed.contains("import ") || trimmed.contains("class ") || trimmed.contains("let ") || trimmed.contains("var ") {
            self.type = .code
        } else {
            self.type = .text
        }
    }

    public var preview: String {
        let singleLine = content.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count > 50 {
            return String(singleLine.prefix(47)) + "..."
        }
        return singleLine
    }

    public var relativeTime: String {
        let diff = Date().timeIntervalSince(timestamp)
        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m ago"
        } else {
            return "\(Int(diff / 3600))h ago"
        }
    }
}

