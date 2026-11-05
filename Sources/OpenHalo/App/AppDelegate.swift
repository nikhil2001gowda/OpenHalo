import Foundation
import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (menu bar utility without dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar extra
        setupStatusBarItem()

        // Launch Dynamic Island window
        IslandWindowController.shared.showIsland(with: AnyView(IslandRootView()))
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "OpenHalo")
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Island", action: #selector(toggleIsland), keyEquivalent: "i")
        toggleItem.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let mediaItem = NSMenuItem(title: "Now Playing Media", action: #selector(showMediaTab), keyEquivalent: "1")
        menu.addItem(mediaItem)

        let calendarItem = NSMenuItem(title: "Calendar & Next Meeting", action: #selector(showCalendarTab), keyEquivalent: "2")
        menu.addItem(calendarItem)

        let timerItem = NSMenuItem(title: "Timers & Pomodoro", action: #selector(showTimerTab), keyEquivalent: "3")
        menu.addItem(timerItem)

        let systemItem = NSMenuItem(title: "System Health & Brightness", action: #selector(showSystemTab), keyEquivalent: "4")
        menu.addItem(systemItem)

        let shelfItem = NSMenuItem(title: "File Shelf & AirDrop", action: #selector(showShelfTab), keyEquivalent: "5")
        menu.addItem(shelfItem)

        let mirrorItem = NSMenuItem(title: "Quick Camera Mirror", action: #selector(showMirrorTab), keyEquivalent: "6")
        menu.addItem(mirrorItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit OpenHalo", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleIsland() {
        Task { @MainActor in
            IslandCoordinator.shared.toggleExpanded()
        }
    }

    @objc private func showMediaTab() {
        Task { @MainActor in
            IslandCoordinator.shared.expandTo(tab: .media)
        }
    }

    @objc private func showCalendarTab() {
        Task { @MainActor in
            IslandCoordinator.shared.expandTo(tab: .calendar)
        }
    }

    @objc private func showTimerTab() {
        Task { @MainActor in
            IslandCoordinator.shared.expandTo(tab: .timers)
        }
    }

    @objc private func showSystemTab() {
        Task { @MainActor in
            IslandCoordinator.shared.expandTo(tab: .system)
        }
    }

    @objc private func showShelfTab() {
        Task { @MainActor in
            IslandCoordinator.shared.expandTo(tab: .shelf)
        }
    }

    @objc private func showMirrorTab() {
        Task { @MainActor in
            IslandCoordinator.shared.expandTo(tab: .mirror)
        }
    }

    @objc private func openPreferences() {
        if settingsWindow == nil {
            let hosting = NSHostingView(rootView: SettingsView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 530),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "OpenHalo Preferences"
            window.contentView = hosting
            window.center()
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
