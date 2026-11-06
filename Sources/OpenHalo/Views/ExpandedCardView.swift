import SwiftUI

public struct ExpandedCardView: View {
    @ObservedObject var coordinator = IslandCoordinator.shared

    public init() {}

    private var hasNotch: Bool {
        ScreenNotchDetector.detect().hasNotch
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Dynamic Island top collar & drop-down accent
            VStack(spacing: 2) {
                if hasNotch {
                    Color.clear
                        .frame(height: 32)
                } else {
                    Color.clear
                        .frame(height: 6)
                }

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 36, height: 3.5)
                    .padding(.bottom, 2)
            }

            // Adaptive Header Tab Strip (10 Feature Tabs) placed strictly below the physical notch
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

                Spacer(minLength: 4)

                // Settings Button
                Button(action: {
                    SettingsWindowManager.shared.show()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.10))
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help("Settings (⌘,)")

                // Collapse Button
                Button(action: {
                    coordinator.collapseToCompact()
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.10))
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help("Collapse Island")
            }
            .padding(.horizontal, 12)
            .padding(.top, hasNotch ? 2 : 10)
            .padding(.bottom, 6)

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, 14)
                .padding(.bottom, 2)

            // Body Content based on activeTab
            tabContent

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                coordinator.expandTo(tab: tab)
            }
        }) {
            HStack(spacing: 3.5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))

                if isSelected {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                if badgeCount > 0 && !isSelected {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 4, height: 4)
                }
            }
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.55))
            .padding(.horizontal, isSelected ? 8 : 6.5)
            .padding(.vertical, 4.5)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.04))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.22) : Color.clear, lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .help(title)
    }
}
