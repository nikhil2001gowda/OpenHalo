import SwiftUI

public struct SettingsView: View {
    @ObservedObject var coordinator = IslandCoordinator.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("OpenHalo Preferences")
                            .font(.system(size: 16, weight: .bold))

                        Text("The Ultimate Native Dynamic Island for macOS")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 4)

                Divider()

                // Display Mode
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display Mode")
                        .font(.system(size: 12, weight: .semibold))

                    Picker("", selection: $coordinator.displayMode) {
                        ForEach(IslandDisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Divider()

                // Compact Pill Wings Customization
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compact Pill Wings (Idle Slots)")
                        .font(.system(size: 12, weight: .semibold))

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Left Wing Slot:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Picker("", selection: $coordinator.leadingSlot) {
                                ForEach(PillLeadingSlot.allCases) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Right Wing Slot:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Picker("", selection: $coordinator.trailingSlot) {
                                ForEach(PillTrailingSlot.allCases) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }

                Divider()

                // Active Modules
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Modules")
                        .font(.system(size: 12, weight: .semibold))

                    Toggle("Now Playing Media (Music & Spotify + Volume Slider)", isOn: $coordinator.enableMediaModule)
                    Toggle("Calendar & Next Meeting Countdown", isOn: $coordinator.enableCalendarModule)
                    Toggle("Productivity Timers & Pomodoro Rings", isOn: $coordinator.enableTimerModule)
                    Toggle("System Telemetry (CPU, Memory, Battery, Brightness)", isOn: $coordinator.enableSystemModule)
                    Toggle("Temporary File Shelf & AirDrop Stash", isOn: $coordinator.enableShelfModule)
                    Toggle("Quick Camera Mirror (Pre-call Appearance Check)", isOn: $coordinator.enableMirrorModule)
                    Toggle("Microphone Privacy Indicator (CoreAudio HAL)", isOn: $coordinator.enableMicIndicator)
                }
                .toggleStyle(.checkbox)

                Divider()

                // Auto Collapse Timing
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Auto-Collapse Delay:")
                            .font(.system(size: 12, weight: .semibold))
                        Text(String(format: "%.1f seconds", coordinator.autoCollapseDelay))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $coordinator.autoCollapseDelay, in: 1.5...8.0, step: 0.5)
                }

                Divider()

                // Footer
                HStack {
                    Button("Reset to Defaults") {
                        coordinator.displayMode = .autoDetect
                        coordinator.autoCollapseDelay = 3.5
                        coordinator.leadingSlot = .auto
                        coordinator.trailingSlot = .auto
                        coordinator.enableMediaModule = true
                        coordinator.enableCalendarModule = true
                        coordinator.enableTimerModule = true
                        coordinator.enableSystemModule = true
                        coordinator.enableShelfModule = true
                        coordinator.enableMirrorModule = true
                        coordinator.enableMicIndicator = true
                    }

                    Spacer()

                    Button("Close") {
                        NSApp.keyWindow?.close()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(22)
        }
        .frame(width: 460, height: 530)
    }
}
