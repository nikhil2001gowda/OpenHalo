import Foundation
import AppKit
import SwiftUI

public final class IslandWindowController: NSObject, ObservableObject {
    public static let shared = IslandWindowController()

    public private(set) var panel: IslandPanel?
    private var screenChangeObserver: Any?

    public override init() {
        super.init()
        setupScreenChangeObserver()
    }

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func showIsland(with rootView: AnyView) {
        let geometry = ScreenNotchDetector.detect()
        let maxPanelWidth: CGFloat = 520
        let maxPanelHeight: CGFloat = 260

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
        let maxPanelHeight: CGFloat = 260

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
}

/// Custom hosting view that allows mouse events to pass through transparent regions outside the visible island
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        // If clicking on root background, return nil so clicks pass through to apps underneath
        if view == self {
            return nil
        }
        return view
    }
}

