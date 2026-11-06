import SwiftUI
import AppKit

@MainActor
public final class SettingsWindowManager {
    public static let shared = SettingsWindowManager()
    private var window: NSWindow?

    public init() {}

    public func show() {
        if window == nil {
            let hosting = NSHostingView(rootView: SettingsView())
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.title = "OpenHalo Settings"
            win.minSize = NSSize(width: 760, height: 520)
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.toolbarStyle = .unified
            win.isMovableByWindowBackground = true
            win.contentView = hosting
            win.center()
            win.isReleasedWhenClosed = false
            self.window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

