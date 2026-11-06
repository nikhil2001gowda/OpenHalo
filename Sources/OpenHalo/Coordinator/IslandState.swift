import Foundation
import SwiftUI

public struct HUDPayload: Equatable, Sendable {
    public enum HUDType: String, Sendable {
        case volume = "Volume"
        case brightness = "Brightness"
        case keyboardBacklight = "Keyboard"
    }

    public let type: HUDType
    public let value: Float        // 0.0 ... 1.0
    public let isMuted: Bool
    public let timestamp: Date

    public init(type: HUDType, value: Float, isMuted: Bool = false, timestamp: Date = Date()) {
        self.type = type
        self.value = max(0.0, min(1.0, value))
        self.isMuted = isMuted
        self.timestamp = timestamp
    }
}

public enum ExpandedTab: String, CaseIterable, Identifiable, Sendable {
    case media = "Media"
    case calendar = "Calendar"
    case timers = "Timer"
    case focus = "Focus"
    case weather = "Weather"
    case clipboard = "Clips"
    case launcher = "Apps"
    case system = "System"
    case shelf = "Shelf"
    case mirror = "Mirror"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .media: return "music.note"
        case .calendar: return "calendar"
        case .timers: return "timer"
        case .focus: return "checklist"
        case .weather: return "cloud.sun.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .launcher: return "square.grid.2x2.fill"
        case .system: return "gauge.medium"
        case .shelf: return "tray.and.arrow.down.fill"
        case .mirror: return "camera.fill"
        }
    }
}

public enum IslandPresentationState: Equatable, Sendable {
    case compact
    case hud(HUDPayload)
    case mediumStatus(title: String, subtitle: String, icon: String, accentColor: Color)
    case expanded(ExpandedTab)
    case shelfDropZone

    public var isExpanded: Bool {
        if case .expanded = self { return true }
        if case .shelfDropZone = self { return true }
        return false
    }

    public var isHUD: Bool {
        if case .hud = self { return true }
        return false
    }

    public static func == (lhs: IslandPresentationState, rhs: IslandPresentationState) -> Bool {
        switch (lhs, rhs) {
        case (.compact, .compact):
            return true
        case let (.hud(h1), .hud(h2)):
            return h1.type == h2.type && abs(h1.value - h2.value) < 0.01 && h1.isMuted == h2.isMuted
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
