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
    @Published public var autoCollapseDelay: Double = 3.5
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

    // MARK: - Dynamic Capsule Dimensions

    public var currentIslandWidth: CGFloat {
        if isDropHovered { return 460 }
        if state.isExpanded { return 430 }
        if case .hud = state { return 230 }
        return 204
    }

    public var currentIslandHeight: CGFloat {
        if isDropHovered { return 120 }
        let notchOffset: CGFloat = ScreenNotchDetector.detect().hasNotch ? 40 : 0
        if state.isExpanded {
            switch activeTab {
            case .mirror: return 215 + notchOffset
            case .calendar: return 190 + notchOffset
            case .media: return 175 + notchOffset
            case .timers: return 165 + notchOffset
            case .system: return 175 + notchOffset
            case .shelf: return 140 + notchOffset
            case .clipboard: return 165 + notchOffset
            case .launcher: return 145 + notchOffset
            case .focus: return 150 + notchOffset
            case .weather: return 145 + notchOffset
            }
        }
        if case .hud = state { return 36 }
        return 34
    }

    private var autoCollapseWorkItem: DispatchWorkItem?
    private var hudDismissWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupSubscriptions()
    }

    private func setupSubscriptions() {
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
            self.showHUD(type: .volume, value: vol, isMuted: isMuted)
        }

        // MediaMate HUD Brightness Listener
        systemControls.onBrightnessChanged = { [weak self] brightness in
            guard let self = self, self.enableHUDOverlay else { return }
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            self.state = .expanded(tab)
        }

        // Start hardware polling when expanded on system tab
        if tab == .system {
            hardwareMonitor.startPolling()
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

        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            self.state = .compact
        }
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
