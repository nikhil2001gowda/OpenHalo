import Foundation
import SwiftUI
import Combine

public enum IslandDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case autoDetect = "Auto Detect (Notch or Floating)"
    case forceFloating = "Always Floating Pill"
    case forceNotch = "Snap to Top Notch"

    public var id: String { rawValue }
}

@MainActor
public final class IslandCoordinator: ObservableObject {
    public static let shared = IslandCoordinator()

    // Presentation state
    @Published public var state: IslandPresentationState = .compact
    @Published public var activeTab: ExpandedTab = .media
    @Published public var isHovering: Bool = false
    @Published public var isDropHovered: Bool = false
    @Published public var requiresKeyboardFocus: Bool = false

    // Preferences
    @Published public var displayMode: IslandDisplayMode = .autoDetect
    @Published public var autoCollapseDelay: Double = 1.2
    @Published public var enableMediaModule: Bool = true
    @Published public var enableCalendarModule: Bool = true
    @Published public var enableTimerModule: Bool = true
    @Published public var enableFocusModule: Bool = true
    @Published public var enableWeatherModule: Bool = true
    @Published public var enableClipboardModule: Bool = true
    @Published public var enableLauncherModule: Bool = true
    @Published public var enableSystemModule: Bool = true
    @Published public var enableShelfModule: Bool = true
    @Published public var enableMirrorModule: Bool = true
    @Published public var enableMicIndicator: Bool = true
    @Published public var enableHUDOverlay: Bool = true
    @Published public var enableFaceLockModule: Bool = false

    // Pill Wing Slots Configuration
    @Published public var leadingSlot: PillLeadingSlot = .auto
    @Published public var trailingSlot: PillTrailingSlot = .auto

    // Subsystem Services
    public let mediaService = MediaService()
    public let audioMonitor = AudioActivityMonitor()
    public let batteryService = BatteryService()
    public let hardwareMonitor = HardwareMonitorService()
    public let timerService = TimerService()
    public let fileShelfService = FileShelfService()
    public let systemControls = SystemControlService()
    public let calendarService = CalendarService()
    public let mirrorService = MirrorService()
    public let clipboardService = ClipboardHistoryService()
    public let appLauncherService = AppLauncherService()
    public let focusService = FocusNoteService()
    public let presenceService = PresenceDetectionService()
    public let weatherService = WeatherService.shared
    public let powerSuspension = PowerSuspensionCoordinator.shared
    public let launchAtLogin = LaunchAtLoginService.shared
    public let screenLockFaceService = ScreenLockFaceService.shared
    public let caffeinateService = CaffeinateService.shared

    // MARK: - Dynamic Capsule Dimensions

    public var hasActiveLiveActivity: Bool {
        if timerService.isRunning { return true }
        if mediaService.currentTrack.isPlaying { return true }
        if let next = calendarService.nextEvent, next.isOngoing { return true }
        return false
    }

    public var currentIslandWidth: CGFloat {
        if isDropHovered { return 460 }
        if state.isExpanded { return 500 }
        let hasNotch = ScreenNotchDetector.detect().hasNotch
        if case .hud = state {
            return hasNotch ? 385 : 240
        }
        if hasActiveLiveActivity {
            return hasNotch ? 385 : 340
        }
        // Idle state: Exactly matches hardware notch (179px) on notched MacBooks
        // Zero awkward ears or outlines sticking out!
        return hasNotch ? 179 : 204
    }

    public var currentIslandHeight: CGFloat {
        if isDropHovered { return 120 }
        let hasNotch = ScreenNotchDetector.detect().hasNotch
        let notchHeight: CGFloat = hasNotch ? 46 : 22

        if state.isExpanded {
            switch activeTab {
            case .calendar: return 290 + notchHeight
            case .mirror: return 245 + notchHeight
            case .media: return 205 + notchHeight
            case .timers: return 195 + notchHeight
            case .system: return 220 + notchHeight
            case .shelf: return 185 + notchHeight
            case .clipboard: return 205 + notchHeight
            case .launcher: return 185 + notchHeight
            case .focus: return 185 + notchHeight
            case .weather: return 215 + notchHeight
            }
        }
        if case .hud = state {
            return hasNotch ? 36 : 34
        }
        // Idle height: Exactly matches hardware notch height (32px) on notched MacBooks
        return hasNotch ? 32 : 34
    }

    private var autoCollapseWorkItem: DispatchWorkItem?
    private var hudDismissWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        // Media track updates trigger Live Activity pill resizing
        mediaService.$currentTrack
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Timer state updates trigger Live Activity pill resizing
        timerService.$isRunning
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        timerService.$remainingSeconds
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Calendar updates
        calendarService.$nextEvent
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Observe timer finish alert
        timerService.$isFinishedAlert
            .dropFirst()
            .sink { [weak self] isAlert in
                guard let self = self else { return }
                if isAlert {
                    self.expandTo(tab: .timers)
                }
            }
            .store(in: &cancellables)

        // Observe file shelf drop target
        fileShelfService.$isDropTargetActive
            .sink { [weak self] isActive in
                guard let self = self else { return }
                if isActive {
                    self.state = .shelfDropZone
                }
            }
            .store(in: &cancellables)

        // MediaMate HUD Volume Listener
        systemControls.onVolumeChanged = { [weak self] vol, isMuted in
            guard let self = self, self.enableHUDOverlay else { return }
            if self.state.isExpanded { return }
            self.showHUD(type: .volume, value: vol, isMuted: isMuted)
        }

        // MediaMate HUD Brightness Listener
        systemControls.onBrightnessChanged = { [weak self] brightness in
            guard let self = self, self.enableHUDOverlay else { return }
            if self.state.isExpanded { return }
            self.showHUD(type: .brightness, value: brightness, isMuted: false)
        }
    }

    public func showHUD(type: HUDPayload.HUDType, value: Float, isMuted: Bool = false) {
        // Do not interrupt expanded work
        if state.isExpanded { return }

        hudDismissWorkItem?.cancel()
        let payload = HUDPayload(type: type, value: value, isMuted: isMuted)

        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            self.state = .hud(payload)
        }
        IslandWindowController.shared.panel?.orderFrontRegardless()

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if case .hud = self.state {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    self.state = .compact
                }
            }
        }
        hudDismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: item)
    }

    public func setKeyboardFocus(_ focus: Bool) {
        self.requiresKeyboardFocus = focus
    }

    public func setHovering(_ hovering: Bool) {
        self.isHovering = hovering
        if hovering {
            cancelAutoCollapse()
            if state == .compact {
                // Smart auto tab selection
                if timerService.isRunning {
                    expandTo(tab: .timers)
                } else if mediaService.currentTrack.isPlaying {
                    expandTo(tab: .media)
                } else if let next = calendarService.nextEvent, next.isOngoing {
                    expandTo(tab: .calendar)
                } else if !fileShelfService.items.isEmpty {
                    expandTo(tab: .shelf)
                } else {
                    expandTo(tab: activeTab)
                }
            }
        } else {
            scheduleAutoCollapse()
        }
    }

    public func expandTo(tab: ExpandedTab) {
        cancelAutoCollapse()
        hudDismissWorkItem?.cancel()

        // Privacy & battery protection: Stop camera if navigating away from Mirror tab
        if activeTab == .mirror && tab != .mirror {
            mirrorService.stopSession()
            presenceService.stopAndCleanup()
        }

        self.activeTab = tab

        withAnimation(AtollAnimations.notchSpring) {
            self.state = .expanded(tab)
        }
        IslandWindowController.shared.panel?.orderFrontRegardless()

        // Start hardware polling and sync brightness when expanded on system tab
        if tab == .system {
            hardwareMonitor.startPolling()
            systemControls.syncHardwareBrightness(isUserAction: false)
        } else {
            hardwareMonitor.stopPolling()
        }

        // Camera session management: start strictly on mirror tab
        if tab == .mirror {
            mirrorService.startSession()
        }
    }

    public func collapseToCompact() {
        cancelAutoCollapse()
        hudDismissWorkItem?.cancel()
        hardwareMonitor.stopPolling()
        mirrorService.stopSession() // Never leave camera running when collapsed
        presenceService.stopAndCleanup()
        setKeyboardFocus(false)

        withAnimation(AtollAnimations.pillSpring) {
            self.state = .compact
        }
        IslandWindowController.shared.panel?.orderFrontRegardless()
    }

    public func toggleExpanded() {
        if state.isExpanded {
            collapseToCompact()
        } else {
            expandTo(tab: activeTab)
        }
    }

    public func scheduleAutoCollapse() {
        cancelAutoCollapse()
        guard state.isExpanded else { return }

        // If user is actively typing or using Camera Mirror, don't auto-collapse
        if activeTab == .mirror || requiresKeyboardFocus {
            return
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !self.isHovering && !self.isDropHovered && !self.requiresKeyboardFocus {
                self.collapseToCompact()
            }
        }
        autoCollapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + autoCollapseDelay, execute: item)
    }

    public func cancelAutoCollapse() {
        autoCollapseWorkItem?.cancel()
        autoCollapseWorkItem = nil
    }
}
