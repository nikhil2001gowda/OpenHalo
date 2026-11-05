import SwiftUI

public struct ExpandedCardView: View {
    @ObservedObject var coordinator = IslandCoordinator.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Tab Selector (6 Modern Tabs)
            HStack(spacing: 2) {
                tabButton(.media, title: "Media", icon: "music.note")
                tabButton(.calendar, title: "Calendar", icon: "calendar")
                tabButton(.timers, title: "Timer", icon: "timer")
                tabButton(.system, title: "System", icon: "gauge.medium")
                tabButton(.shelf, title: "Shelf", icon: "tray.and.arrow.down.fill", badgeCount: coordinator.fileShelfService.items.count)
                tabButton(.mirror, title: "Mirror", icon: "camera.fill")

                Spacer()

                // Collapse Button
                Button(action: {
                    coordinator.collapseToCompact()
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 14)

            // Body Content based on activeTab
            Group {
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
                    MirrorExpandedView(mirrorService: coordinator.mirrorService)
                }
            }
        }
    }

    private func tabButton(_ tab: ExpandedTab, title: String, icon: String, badgeCount: Int = 0) -> some View {
        Button(action: {
            coordinator.expandTo(tab: tab)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))

                Text(title)
                    .font(.system(size: 10, weight: .medium))

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 8.5, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(coordinator.activeTab == tab ? .white : Color.white.opacity(0.5))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(coordinator.activeTab == tab ? Color.white.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
