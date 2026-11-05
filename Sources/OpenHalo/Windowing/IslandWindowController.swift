import Foundation
import AppKit
import SwiftUI

public final class IslandWindowController: NSObject, ObservableObject {
    public static let shared = IslandWindowController()

    public private(set) var panel: IslandPanel?
    private var screenChangeObserver: Any?
    private var clickOutsideMonitor: Any?

    public override init() {
        super.init()
        setupScreenChangeObserver()
        setupGlobalClickOutsideMonitor()
    }

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    public func showIsland(with rootView: AnyView) {
        let geometry = ScreenNotchDetector.detect()
        let maxPanelWidth: CGFloat = 520
        let maxPanelHeight: CGFloat = 340

        let screenFrame = geometry.screenFrame
        let originX = screenFrame.midX - (maxPanelWidth / 2.0)
        let originY = screenFrame.maxY - maxPanelHeight

        let initialRect = NSRect(
            x: originX,
            y: originY,
            width: maxPanelWidth,
            height: maxPanelHeight
        )

        let newPanel = IslandPanel(contentRect: initialRect)
        let hostingView = PassthroughHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: maxPanelWidth, height: maxPanelHeight)
        hostingView.autoresizingMask = [.width, .height]

        newPanel.contentView = hostingView
        newPanel.orderFrontRegardless()
        self.panel = newPanel
    }

    public func reposition() {
        guard let panel = panel else { return }
        let geometry = ScreenNotchDetector.detect()
        let maxPanelWidth: CGFloat = 520
        let maxPanelHeight: CGFloat = 340

        let screenFrame = geometry.screenFrame
        let originX = screenFrame.midX - (maxPanelWidth / 2.0)
        let originY = screenFrame.maxY - maxPanelHeight

        panel.setFrame(
            NSRect(x: originX, y: originY, width: maxPanelWidth, height: maxPanelHeight),
            display: true,
            animate: false
        )
    }

    private func setupScreenChangeObserver() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reposition()
        }
    }

    private func setupGlobalClickOutsideMonitor() {
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self = self, let panel = self.panel else { return }
                let coordinator = IslandCoordinator.shared

                // Only dismiss when expanded
                guard coordinator.state.isExpanded else { return }

                let mouseLocation = NSEvent.mouseLocation
                let currentWidth = coordinator.currentIslandWidth
                let currentHeight = coordinator.currentIslandHeight

                let minX = panel.frame.midX - (currentWidth / 2.0)
                let minY = panel.frame.maxY - currentHeight
                let islandScreenRect = NSRect(x: minX, y: minY, width: currentWidth, height: currentHeight)

                if !islandScreenRect.contains(mouseLocation) {
                    coordinator.collapseToCompact()
                }
            }
        }
    }
}

/// Custom hosting view that allows mouse events to pass through transparent regions outside the visible island
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let coordinator = IslandCoordinator.shared
        let currentWidth = coordinator.currentIslandWidth
        let currentHeight = coordinator.currentIslandHeight

        let minX = (bounds.width - currentWidth) / 2.0
        let minY = bounds.height - currentHeight

        let islandRect = NSRect(x: minX, y: minY, width: currentWidth, height: currentHeight)

        // If clicking inside the visible island capsule, return self so clicks reach SwiftUI buttons!
        if islandRect.contains(point) {
            return super.hitTest(point)
        }

        // If clicking on empty background margins outside the island while expanded, collapse to compact!
        if coordinator.state.isExpanded {
            Task { @MainActor in
                coordinator.collapseToCompact()
            }
        }

        // Pass clicks through to apps underneath
        return nil
    }
}
