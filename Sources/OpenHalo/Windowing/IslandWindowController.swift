import Foundation
import AppKit
import SwiftUI

@MainActor
public final class IslandWindowController: NSObject, ObservableObject {
    public static let shared = IslandWindowController()

    public private(set) var panel: IslandPanel?
    private var screenChangeObserver: Any?
    private var spaceChangeObserver: Any?
    private var clickOutsideGlobalMonitor: Any?
    private var clickOutsideLocalMonitor: Any?
    private var appActivationObserver: Any?
    private var orderFrontTimer: Timer?

    public override init() {
        super.init()
        setupScreenChangeObserver()
        setupClickOutsideMonitors()
    }

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
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
        orderFrontTimer?.invalidate()
    }

    public func showIsland(with rootView: AnyView) {
        let geometry = ScreenNotchDetector.detect()
        let maxPanelWidth: CGFloat = 580
        let maxPanelHeight: CGFloat = 380

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
        let maxPanelWidth: CGFloat = 580
        let maxPanelHeight: CGFloat = 380
        let screenFrame = geometry.screenFrame
        let originX = screenFrame.midX - (maxPanelWidth / 2.0)
        let originY = screenFrame.maxY - maxPanelHeight

        panel.setFrame(
            NSRect(x: originX, y: originY, width: maxPanelWidth, height: maxPanelHeight),
            display: true,
            animate: false
        )
        panel.orderFrontRegardless()
    }

    private func setupScreenChangeObserver() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reposition()
            }
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
                    // Do not auto-collapse while on Mirror tab so user can freely interact with macOS Video Effects (Center Stage / Studio Light) in menu bar
                    if coordinator.activeTab == .mirror { return }
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
                    // Do not auto-collapse while on Mirror tab so user can freely interact with macOS Video Effects (Center Stage / Studio Light) in menu bar
                    if coordinator.activeTab == .mirror { return }

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

        // 3. Workspace App Activation Observer: Keep panel floating above newly active app, auto-collapse if expanded
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.panel?.orderFrontRegardless()
                let coordinator = IslandCoordinator.shared
                if coordinator.state.isExpanded {
                    // Do not auto-collapse while on Mirror tab so user can freely interact with macOS Video Effects (Center Stage / Studio Light) in menu bar
                    if coordinator.activeTab == .mirror { return }
                    coordinator.collapseToCompact()
                }
            }
        }

        // 4. Space Change Observer: Stay on top when user switches virtual desktops / full-screen spaces
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.panel?.orderFrontRegardless()
            }
        }
    }
}

/// Custom hosting view that allows mouse events to pass through transparent regions outside the visible island
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    private static var acceptedDragTypes: [NSPasteboard.PasteboardType] {
        [
            .fileURL,
            .URL,
            .string,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("com.apple.finder.node")
        ]
    }

    @MainActor required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes(Self.acceptedDragTypes)
    }

    @MainActor required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(Self.acceptedDragTypes)
    }

    // MARK: - NSDraggingDestination Implementation (Drop Support)

    private func pasteboardHasFiles(_ pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        let accepted: Set<String> = [
            NSPasteboard.PasteboardType.fileURL.rawValue,
            NSPasteboard.PasteboardType.URL.rawValue,
            "NSFilenamesPboardType",
            "public.file-url",
            "com.apple.finder.node"
        ]
        return types.contains { accepted.contains($0.rawValue) }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        Task { @MainActor in
            let coordinator = IslandCoordinator.shared
            coordinator.fileShelfService.isDropTargetActive = true
            coordinator.isDropHovered = true
            if !coordinator.state.isExpanded {
                coordinator.expandTo(tab: .shelf)
            }
        }
        _ = super.draggingEntered(sender)
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        _ = super.draggingUpdated(sender)
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        super.draggingExited(sender)
        Task { @MainActor in
            let coordinator = IslandCoordinator.shared
            coordinator.fileShelfService.isDropTargetActive = false
            coordinator.isDropHovered = false
        }
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = FileDropResolver.resolveURLs(from: sender.draggingPasteboard)
        _ = super.performDragOperation(sender)

        Task { @MainActor in
            let coordinator = IslandCoordinator.shared
            coordinator.fileShelfService.isDropTargetActive = false
            coordinator.isDropHovered = false
            if !urls.isEmpty {
                coordinator.fileShelfService.addFiles(urls)
                coordinator.expandTo(tab: .shelf)
            }
        }
        return true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Convert window coordinate point to view local coordinate space (with isFlipped == true, y=0 is at the top/notch)
        let localPoint = convert(point, from: nil)

        let coordinator = IslandCoordinator.shared
        let currentWidth = coordinator.currentIslandWidth
        let currentHeight = coordinator.currentIslandHeight

        let minX = (bounds.width - currentWidth) / 2.0
        let islandRect = NSRect(x: minX, y: 0, width: currentWidth, height: currentHeight)

        // Drop zone around the notch: generous hit target so dragged files never get discarded
        let dropZone = NSRect(
            x: (bounds.width - max(currentWidth, 340)) / 2.0,
            y: 0,
            width: max(currentWidth, 340),
            height: max(currentHeight, 60)
        )

        // If cursor/drag is inside visible island or drop zone, return view so SwiftUI and dragging receive events
        if islandRect.contains(localPoint) || dropZone.contains(localPoint) {
            return super.hitTest(point) ?? self
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
