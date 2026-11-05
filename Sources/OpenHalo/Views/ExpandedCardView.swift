import SwiftUI

public struct ExpandedCardView: View {
    @ObservedObject var coordinator = IslandCoordinator.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Adaptive Header Tab Strip (10 Feature Tabs)
            HStack(spacing: 4) {
                tabButton(.media, title: "Media", icon: "music.note")
                tabButton(.calendar, title: "Calendar", icon: "calendar")
                tabButton(.timers, title: "Timer", icon: "timer")
                tabButton(.focus, title: "Focus", icon: "checklist")
                tabButton(.weather, title: "Weather", icon: "cloud.sun.fill")
                tabButton(.clipboard, title: "Clips", icon: "doc.on.clipboard.fill", badgeCount: coordinator.clipboardService.items.count)
                tabButton(.launcher, title: "Apps", icon: "square.grid.2x2.fill")
                tabButton(.system, title: "System", icon: "gauge.medium")
                tabButton(.shelf, title: "Shelf", icon: "tray.and.arrow.down.fill", badgeCount: coordinator.fileShelfService.items.count)
                tabButton(.mirror, title: "Mirror", icon: "camera.fill")

                Spacer()

                // Collapse Button
                Button(action: {
                    coordinator.collapseToCompact()
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, ScreenNotchDetector.detect().hasNotch ? 40 : 10)
            .padding(.bottom, 4)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 12)

            // Body Content based on activeTab
            tabContent
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch coordinator.activeTab {
        case .media:
            MediaExpandedView(
                mediaService: coordinator.mediaService,
                systemControls: coordinator.systemControls
            )
        case .calendar:
            CalendarExpandedView(calendarService: coordinator.calendarService)
        case .timers:
            TimerExpandedView(timerService: coordinator.timerService)
        case .focus:
            FocusNoteExpandedView(focusService: coordinator.focusService)
        case .weather:
            WeatherExpandedView(weatherService: coordinator.weatherService)
        case .clipboard:
            ClipboardExpandedView(clipboardService: coordinator.clipboardService)
        case .launcher:
            LauncherExpandedView(launcherService: coordinator.appLauncherService)
        case .system:
            SystemHealthView(
                hardwareMonitor: coordinator.hardwareMonitor,
                batteryService: coordinator.batteryService,
                audioMonitor: coordinator.audioMonitor,
                systemControls: coordinator.systemControls
            )
        case .shelf:
            FileShelfView(fileShelfService: coordinator.fileShelfService)
        case .mirror:
            MirrorExpandedView(
                mirrorService: coordinator.mirrorService,
                presenceService: coordinator.presenceService
            )
        }
    }

    private func tabButton(_ tab: ExpandedTab, title: String, icon: String, badgeCount: Int = 0) -> some View {
        let isSelected = coordinator.activeTab == tab

        return Button(action: {
            coordinator.expandTo(tab: tab)
        }) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))

                if isSelected {
                    Text(title)
                        .font(.system(size: 9.5, weight: .medium))
                }

                if badgeCount > 0 && !isSelected {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 4, height: 4)
                }
            }
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.55))
            .padding(.horizontal, isSelected ? 8 : 6)
            .padding(.vertical, 4)
            .background(
                isSelected ?
                    Color.white.opacity(0.2) :
                    Color.white.opacity(0.04)
            )
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
