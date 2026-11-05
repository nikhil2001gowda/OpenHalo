import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject var coordinator = IslandCoordinator.shared
    @ObservedObject var loginService = LaunchAtLoginService.shared
    @ObservedObject var faceService = ScreenLockFaceService.shared
    @ObservedObject var powerCoordinator = PowerSuspensionCoordinator.shared
    @ObservedObject var weatherService = WeatherService.shared

    @State private var isShowingEnrollmentSheet: Bool = false
    @State private var macPassword: String = ""
    @State private var hasStoredPassword: Bool = KeychainHelper.hasPassword()
    @State private var passwordStatusMessage: String? = nil

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 12) {
                    GlassyHaloLogoView(size: 34)

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

                // Boot & Power Management (Glance-Style Zero CPU Engine)
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Lifecycle & Power Preservation")
                        .font(.system(size: 12, weight: .semibold))

                    Toggle("Launch OpenHalo at Login (macOS SMAppService)", isOn: $loginService.isEnabled)
                        .toggleStyle(.checkbox)

                    HStack(spacing: 8) {
                        Image(systemName: "bolt.badge.clock.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))

                        Text("Glance Low-Power Engine: Active (Freezes all Mach/HAL loops during sleep. Sleep events: \(powerCoordinator.sleepCount))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Lock Screen Face ID Assistant (5-Second Hard Limit)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Lock Screen Face ID Assistant")
                            .font(.system(size: 12, weight: .semibold))

                        Spacer()

                        Text("Max 5.0s Camera Burst")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    Toggle("Enable Face ID Recognition on Lock Wake", isOn: $faceService.isFaceAssistEnabled)
                        .toggleStyle(.checkbox)

                    Text("Runs strictly upon screen lock wake using on-device Apple Vision. Zero cloud, zero video files stored. Camera forcibly killed at 5s or upon instant match.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Button(faceService.hasEnrolledFace ? "Re-Enroll Face Profile" : "Enroll Face Profile") {
                            isShowingEnrollmentSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        if faceService.hasEnrolledFace {
                            Button("Clear Profile") {
                                faceService.clearEnrolledFace()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Text("Status: Enrolled (Local Key)")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                    }

                    // Auto-Unlock Password via Secure Keychain
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mac Auto-Unlock Login Password (Glance Architecture):")
                            .font(.system(size: 11, weight: .medium))

                        HStack(spacing: 8) {
                            SecureField(hasStoredPassword ? "•••••••••••• (Saved)" : "Enter macOS User Password", text: $macPassword)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 240)

                            Button("Save to Keychain") {
                                if !macPassword.isEmpty {
                                    if KeychainHelper.savePassword(macPassword) {
                                        hasStoredPassword = true
                                        passwordStatusMessage = "Encrypted in macOS Keychain"
                                        macPassword = ""
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(macPassword.isEmpty)

                            if hasStoredPassword {
                                Button("Remove") {
                                    KeychainHelper.deletePassword()
                                    hasStoredPassword = false
                                    passwordStatusMessage = "Removed"
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(hasStoredPassword ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)

                            Text(hasStoredPassword ? "Keychain: Encrypted & Ready for Auto-Unlock" : "Optional: Save password to enable instant keystroke unlock on wake")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            if let msg = passwordStatusMessage {
                                Text("• \(msg)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.cyan)
                            }
                        }

                        // Test Face ID Notch Animation Button
                        Button(action: {
                            coordinator.showFaceIDScan(isScanning: true, isUnlocked: false)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                SoundEffectManager.playActionBeep()
                                coordinator.showFaceIDScan(isScanning: false, isUnlocked: true)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "faceid")
                                Text("Test Face ID Notch HUD & Animation")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
                .sheet(isPresented: $isShowingEnrollmentSheet) {
                    FaceIDEnrollmentView(faceService: faceService) {
                        isShowingEnrollmentSheet = false
                    }
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
                    Text("Active Modules & Capabilities")
                        .font(.system(size: 12, weight: .semibold))

                    Toggle("Native iOS HUD Popups (Volume & Brightness Overlays)", isOn: $coordinator.enableHUDOverlay)
                    Toggle("Now Playing Media (Music & Spotify + Volume Slider)", isOn: $coordinator.enableMediaModule)
                    Toggle("Live Weather (Open-Meteo Keyless Service)", isOn: $coordinator.enableWeatherModule)
                    Toggle("Calendar & Next Meeting Countdown", isOn: $coordinator.enableCalendarModule)
                    Toggle("Clipboard History Manager & Search", isOn: $coordinator.enableClipboardModule)
                    Toggle("Quick App & Web Bookmarks Launcher", isOn: $coordinator.enableLauncherModule)
                    Toggle("Focus Objective & Daily Task Ticker", isOn: $coordinator.enableFocusModule)
                    Toggle("Productivity Timers & Pomodoro Rings", isOn: $coordinator.enableTimerModule)
                    Toggle("System Telemetry (CPU, Memory, Battery, Brightness)", isOn: $coordinator.enableSystemModule)
                    Toggle("Temporary File Shelf & SIPS Image Converter", isOn: $coordinator.enableShelfModule)
                    Toggle("Quick Camera Mirror & On-Device Vision Check", isOn: $coordinator.enableMirrorModule)
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
                        coordinator.enableWeatherModule = true
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
        .frame(width: 480, height: 600)
    }
}
