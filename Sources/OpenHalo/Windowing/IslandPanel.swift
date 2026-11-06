import Foundation
import AppKit

public final class IslandPanel: NSPanel {
    /// Above regular, menu-bar, screen-saver, and assistive overlays. The
    /// shielding level is the highest public Core Graphics window tier.
    public static let overlayWindowLevel = NSWindow.Level(
        rawValue: Int(CGShieldingWindowLevel()) + 1
    )

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = Self.overlayWindowLevel
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
        self.registerForDraggedTypes([.fileURL, .URL, .string])
    }

    public override var canBecomeKey: Bool {
        IslandCoordinator.shared.state.isExpanded || IslandCoordinator.shared.requiresKeyboardFocus
    }

    public override var canBecomeMain: Bool {
        false
    }
}
