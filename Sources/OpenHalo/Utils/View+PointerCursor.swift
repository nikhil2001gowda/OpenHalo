import SwiftUI
import AppKit

public struct PointingHandCursorModifier: ViewModifier {
    public let enabled: Bool

    public func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside && enabled {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
    }
}

public extension View {
    func pointingHandCursor(enabled: Bool = true) -> some View {
        self.modifier(PointingHandCursorModifier(enabled: enabled))
    }
}

