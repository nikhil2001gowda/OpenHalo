import Foundation
import AppKit

public enum ShortcutType: String, Sendable, Codable {
    case application
    case url
}

public struct LauncherShortcut: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public var name: String
    public var target: String // App bundle ID or URL string
    public var type: ShortcutType
    public var sfSymbol: String

    public init(id: UUID = UUID(), name: String, target: String, type: ShortcutType, sfSymbol: String) {
        self.id = id
        self.name = name
        self.target = target
        self.type = type
        self.sfSymbol = sfSymbol
    }

    public static let defaults: [LauncherShortcut] = [
        LauncherShortcut(name: "Finder", target: "/System/Library/CoreServices/Finder.app", type: .application, sfSymbol: "folder.fill"),
        LauncherShortcut(name: "Safari", target: "/Applications/Safari.app", type: .application, sfSymbol: "safari.fill"),
        LauncherShortcut(name: "Terminal", target: "/System/Applications/Utilities/Terminal.app", type: .application, sfSymbol: "terminal.fill"),
        LauncherShortcut(name: "Notes", target: "/System/Applications/Notes.app", type: .application, sfSymbol: "note.text"),
        LauncherShortcut(name: "GitHub", target: "https://github.com", type: .url, sfSymbol: "globe"),
        LauncherShortcut(name: "Google", target: "https://google.com", type: .url, sfSymbol: "magnifyingglass")
    ]
}

