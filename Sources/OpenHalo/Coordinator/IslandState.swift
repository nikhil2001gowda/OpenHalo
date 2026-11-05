import Foundation
import SwiftUI

public enum ExpandedTab: String, CaseIterable, Identifiable, Sendable {
    case media = "Media"
    case calendar = "Calendar"
    case timers = "Timer"
    case system = "System"
    case shelf = "Shelf"
    case mirror = "Mirror"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .media: return "music.note"
        case .calendar: return "calendar"
        case .timers: return "timer"
        case .system: return "gauge.medium"
        case .shelf: return "tray.and.arrow.down.fill"
        case .mirror: return "camera.fill"
        }
    }
}

public enum IslandPresentationState: Equatable, Sendable {
    case compact
    case mediumStatus(title: String, subtitle: String, icon: String, accentColor: Color)
    case expanded(ExpandedTab)
    case shelfDropZone

    public var isExpanded: Bool {
        if case .expanded = self { return true }
        if case .shelfDropZone = self { return true }
        return false
    }

    public static func == (lhs: IslandPresentationState, rhs: IslandPresentationState) -> Bool {
        switch (lhs, rhs) {
        case (.compact, .compact):
            return true
        case let (.mediumStatus(t1, s1, i1, _), .mediumStatus(t2, s2, i2, _)):
            return t1 == t2 && s1 == s2 && i1 == i2
        case let (.expanded(tab1), .expanded(tab2)):
            return tab1 == tab2
        case (.shelfDropZone, .shelfDropZone):
            return true
        default:
            return false
        }
    }
}
