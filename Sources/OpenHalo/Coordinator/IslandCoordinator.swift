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

    // Preferences
    @Published public var displayMode: IslandDisplayMode = .autoDetect
    @Published public var autoCollapseDelay: Double = 3.5
    @Published public var enableMediaModule: Bool = true
    @Published public var enableCalendarModule: Bool = true
    @Published public var enableTimerModule: Bool = true
    @Published public var enableSystemModule: Bool = true
    @Published public var enableShelfModule: Bool = true
    @Published public var enableMirrorModule: Bool = true
    @Published public var enableMicIndicator: Bool = true

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

    private var autoCollapseWorkItem: DispatchWorkItem?
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

        // Privacy & battery protection: Stop camera if navigating away from Mirror tab
        if activeTab == .mirror && tab != .mirror {
            mirrorService.stopSession()
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
        hardwareMonitor.stopPolling()
        mirrorService.stopSession() // Never leave camera running when collapsed

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

        // If user is actively using the Camera Mirror, don't auto-collapse
        if activeTab == .mirror {
            return
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !self.isHovering && !self.isDropHovered {
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
