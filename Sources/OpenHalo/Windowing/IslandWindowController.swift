import Foundation
import AppKit
import SwiftUI

@MainActor
public final class IslandWindowController: NSObject, ObservableObject {
    public static let shared = IslandWindowController()

    public private(set) var panel: IslandPanel?
    private var screenChangeObserver: Any?
    private var clickOutsideGlobalMonitor: Any?
    private var clickOutsideLocalMonitor: Any?
    private var appActivationObserver: Any?

    public override init() {
        super.init()
        setupScreenChangeObserver()
        setupClickOutsideMonitors()
    }

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let monitor = clickOutsideGlobalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = clickOutsideLocalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
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
        let isExpanded = IslandCoordinator.shared.state.isExpanded
        updateFrameForState(isExpanded: isExpanded)
    }

    public func updateFrameForState(isExpanded: Bool) {
        guard let panel = panel else { return }
        let geometry = ScreenNotchDetector.detect()
        let screenFrame = geometry.screenFrame

        if isExpanded {
            // Full screen transparent canvas to capture clicks outside anywhere on the display
            panel.setFrame(screenFrame, display: true, animate: false)
        } else {
            let maxPanelWidth: CGFloat = 520
            let maxPanelHeight: CGFloat = 340
            let originX = screenFrame.midX - (maxPanelWidth / 2.0)
            let originY = screenFrame.maxY - maxPanelHeight

            panel.setFrame(
                NSRect(x: originX, y: originY, width: maxPanelWidth, height: maxPanelHeight),
                display: true,
                animate: false
            )
        }
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

    private func setupClickOutsideMonitors() {
        // 1. Global Monitor: Captures clicks outside OpenHalo when another application has focus
        clickOutsideGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { _ in
            Task { @MainActor in
                let coordinator = IslandCoordinator.shared
                if coordinator.state.isExpanded {
                    coordinator.collapseToCompact()
                }
            }
        }

        // 2. Local Monitor: Captures clicks inside OpenHalo window
        clickOutsideLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self = self, let panel = self.panel else { return event }
            Task { @MainActor in
                let coordinator = IslandCoordinator.shared

                if coordinator.state.isExpanded {
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
            return event
        }

        // 3. Workspace App Activation Observer: Auto-collapse if user activates any other app
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                let coordinator = IslandCoordinator.shared
                if coordinator.state.isExpanded {
                    coordinator.collapseToCompact()
                }
            }
        }
    }
}

/// Custom hosting view that allows mouse events to pass through transparent regions outside the visible island
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Convert window coordinate point to view local coordinate space (where isFlipped == true, y=0 is at the top)
        let localPoint = convert(point, from: nil)

        let coordinator = IslandCoordinator.shared
        let currentWidth = coordinator.currentIslandWidth
        let currentHeight = coordinator.currentIslandHeight

        let minX = (bounds.width - currentWidth) / 2.0
        let islandRect = NSRect(x: minX, y: 0, width: currentWidth, height: currentHeight)

        // If clicking inside the visible island capsule, return the view so SwiftUI buttons/sliders receive the event!
        if islandRect.contains(localPoint) {
            return super.hitTest(point)
        }

        // When expanded, intercept clicks outside the island capsule to dismiss immediately
        if coordinator.state.isExpanded {
            return self
        }

        // When compact, pass clicks through to apps underneath (zero side effects in hitTest)
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        let coordinator = IslandCoordinator.shared
        if coordinator.state.isExpanded {
            let localPoint = convert(event.locationInWindow, from: nil)
            let currentWidth = coordinator.currentIslandWidth
            let currentHeight = coordinator.currentIslandHeight
            let minX = (bounds.width - currentWidth) / 2.0
            let islandRect = NSRect(x: minX, y: 0, width: currentWidth, height: currentHeight)

            if !islandRect.contains(localPoint) {
                coordinator.collapseToCompact()
                return
            }
        }
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let coordinator = IslandCoordinator.shared
        if coordinator.state.isExpanded {
            coordinator.collapseToCompact()
            return
        }
        super.rightMouseDown(with: event)
    }
}
