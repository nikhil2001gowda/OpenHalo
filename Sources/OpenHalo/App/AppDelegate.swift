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

        // Start Glance Lockscreen Face ID Engine
        GlanceCoordinator.shared.start()

        // Setup global keyboard shortcuts
        setupKeyboardShortcuts()

        // Check first-run permissions
        checkFirstLaunchPermissions()

        // Visually present Preferences window so user immediately sees OpenHalo is active
        Task { @MainActor in
            SettingsWindowManager.shared.show()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            SettingsWindowManager.shared.show()
            IslandCoordinator.shared.toggleExpanded()
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    private func checkFirstLaunchPermissions() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "OpenHalo.HasLaunchedBefore")
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: "OpenHalo.HasLaunchedBefore")
            // Proactively request Accessibility on first launch so lock-screen features are pre-approved
            if !KeystrokeInjector.isAccessibilityTrusted() {
                KeystrokeInjector.promptForAccessibility()
            }
        }
    }

    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?

    private func setupKeyboardShortcuts() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Handle synchronously on main thread for local window events
            if let self = self {
                if MainActor.assumeIsolated({ self.handleKeyEvent(event) }) {
                    return nil
                }
            }
            return event
        }
    }

    @discardableResult
    @MainActor
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers?.lowercased()

        // 1. Command + Shift + V -> Open Clipboard History
        if flags == [.command, .shift] && chars == "v" {
            Task { @MainActor in
                IslandCoordinator.shared.expandTo(tab: .clipboard)
            }
            return true
        }

        // 2. Command + Shift + M -> Open Media Player
        if flags == [.command, .shift] && chars == "m" {
            Task { @MainActor in
                IslandCoordinator.shared.expandTo(tab: .media)
            }
            return true
        }

        // 3. Option + Space -> Toggle Island / Launcher
        if flags == .option && event.keyCode == 49 { // 49 is Spacebar
            Task { @MainActor in
                IslandCoordinator.shared.toggleExpanded()
            }
            return true
        }

        // 4. Escape -> Immediate Collapse to Compact
        if event.keyCode == 53 { // 53 is Escape
            if IslandCoordinator.shared.state.isExpanded {
                Task { @MainActor in
                    IslandCoordinator.shared.collapseToCompact()
                }
                return true
            }
        }

        return false
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "OpenHalo")
            button.toolTip = "OpenHalo — Dynamic Island & Face ID"
        }

        let menu = NSMenu()

        let prefItem = NSMenuItem(title: "OpenHalo Preferences & Face ID...", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(prefItem)

        let toggleItem = NSMenuItem(title: "Toggle Dynamic Island", action: #selector(toggleIsland), keyEquivalent: "i")
        toggleItem.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let mediaItem = NSMenuItem(title: "Now Playing Media", action: #selector(showMediaTab), keyEquivalent: "1")
        menu.addItem(mediaItem)

        let calendarItem = NSMenuItem(title: "Calendar & Next Meeting", action: #selector(showCalendarTab), keyEquivalent: "2")
        menu.addItem(calendarItem)

        let timerItem = NSMenuItem(title: "Timers & Pomodoro", action: #selector(showTimerTab), keyEquivalent: "3")
        menu.addItem(timerItem)

        let focusItem = NSMenuItem(title: "Focus Task & Notes", action: #selector(showFocusTab), keyEquivalent: "4")
        menu.addItem(focusItem)

        let weatherItem = NSMenuItem(title: "Live Weather Forecast", action: #selector(showWeatherTab), keyEquivalent: "w")
        menu.addItem(weatherItem)

        let clipboardItem = NSMenuItem(title: "Clipboard History Manager", action: #selector(showClipboardTab), keyEquivalent: "5")
        menu.addItem(clipboardItem)

        let launcherItem = NSMenuItem(title: "App & Bookmark Launcher", action: #selector(showLauncherTab), keyEquivalent: "6")
        menu.addItem(launcherItem)

        let systemItem = NSMenuItem(title: "System Health & Brightness", action: #selector(showSystemTab), keyEquivalent: "7")
        menu.addItem(systemItem)

        let shelfItem = NSMenuItem(title: "File Shelf & AirDrop", action: #selector(showShelfTab), keyEquivalent: "8")
        menu.addItem(shelfItem)

        let mirrorItem = NSMenuItem(title: "Quick Camera Mirror & Vision", action: #selector(showMirrorTab), keyEquivalent: "9")
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

    @objc private func showFocusTab() {
        Task { @MainActor in
            IslandCoordinator.shared.expandTo(tab: .focus)
        }
    }

    @objc private func showWeatherTab() {
        Task { @MainActor in
            IslandCoordinator.shared.expandTo(tab: .weather)
        }
    }

    @objc private func showClipboardTab() {
        Task { @MainActor in
            IslandCoordinator.shared.expandTo(tab: .clipboard)
        }
    }

    @objc private func showLauncherTab() {
        Task { @MainActor in
            IslandCoordinator.shared.expandTo(tab: .launcher)
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
        Task { @MainActor in
            SettingsWindowManager.shared.show()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
