import Foundation
import AppKit

public final class IslandPanel: NSPanel, NSDraggingDestination {
    /// Floating above all standard apps and the menu bar, fully accessible to the macOS Drag Manager
    public static let overlayWindowLevel = NSWindow.Level.statusBar

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // isFloatingPanel = false prevents AppKit from demoting the window level when other applications activate
        self.isFloatingPanel = false
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
        self.worksWhenModal = true
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
        self.registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("com.apple.finder.node")
        ])
    }

    // MARK: - Direct Window Drag Destination Fallback

    public func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        Task { @MainActor in
            let coordinator = IslandCoordinator.shared
            coordinator.fileShelfService.isDropTargetActive = true
            coordinator.isDropHovered = true
            if !coordinator.state.isExpanded {
                coordinator.expandTo(tab: .shelf)
            }
        }
        return (contentView?.draggingEntered(sender) ?? .copy)
    }

    public func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return (contentView?.draggingUpdated(sender) ?? .copy)
    }

    public func draggingExited(_ sender: (any NSDraggingInfo)?) {
        contentView?.draggingExited(sender)
        Task { @MainActor in
            let coordinator = IslandCoordinator.shared
            coordinator.fileShelfService.isDropTargetActive = false
            coordinator.isDropHovered = false
        }
    }

    public func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = FileDropResolver.resolveURLs(from: sender.draggingPasteboard)
        let handled = contentView?.performDragOperation(sender) ?? false

        Task { @MainActor in
            let coordinator = IslandCoordinator.shared
            coordinator.fileShelfService.isDropTargetActive = false
            coordinator.isDropHovered = false
            if !urls.isEmpty {
                coordinator.fileShelfService.addFiles(urls)
                coordinator.expandTo(tab: .shelf)
            }
        }
        return !urls.isEmpty || handled
    }

    public override var canBecomeKey: Bool {
        IslandCoordinator.shared.state.isExpanded || IslandCoordinator.shared.requiresKeyboardFocus
    }

    public override var canBecomeMain: Bool {
        false
    }

    private var lastSwipeSkipTime: Date = .distantPast

    public override func scrollWheel(with event: NSEvent) {
        let absX = abs(event.deltaX)
        let absY = abs(event.deltaY)

        // Droppy Parity: Horizontal 2-finger swipe over compact pill skips songs without opening the panel
        if absX > absY && absX > 2.0 {
            Task { @MainActor in
                let coordinator = IslandCoordinator.shared
                if !coordinator.state.isExpanded && Date().timeIntervalSince(self.lastSwipeSkipTime) > 0.5 {
                    self.lastSwipeSkipTime = Date()
                    if event.deltaX < -2.0 {
                        coordinator.mediaService.nextTrack()
                    } else if event.deltaX > 2.0 {
                        coordinator.mediaService.previousTrack()
                    }
                }
            }
        } else if event.deltaY < -1.5 {
            // Swipe / scroll down opens the shelf
            Task { @MainActor in
                let coordinator = IslandCoordinator.shared
                if !coordinator.state.isExpanded {
                    coordinator.expandTo(tab: coordinator.activeTab)
                }
            }
        } else if event.deltaY > 2.0 {
            // Swipe / scroll up collapses the shelf
            Task { @MainActor in
                let coordinator = IslandCoordinator.shared
                if coordinator.state.isExpanded {
                    coordinator.collapseToCompact()
                }
            }
        }
        super.scrollWheel(with: event)
    }
}
