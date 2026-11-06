import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject var coordinator = IslandCoordinator.shared
    @ObservedObject var loginService = LaunchAtLoginService.shared
    @ObservedObject var faceService = ScreenLockFaceService.shared
    @ObservedObject var powerCoordinator = PowerSuspensionCoordinator.shared
    @ObservedObject var weatherService = WeatherService.shared

    @State private var glanceSettings = GlanceSettings.shared
    @State private var enrollmentStore = FaceEnrollmentStore.shared
    @State private var macPassword: String = ""
    @State private var hasStoredPassword: Bool = KeychainHelper.hasPassword()
    @State private var passwordStatusMessage: String? = nil
    @State private var showAdvancedGlanceSettings: Bool = true

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                Divider()
                displayModeSection
                Divider()
                systemLifecycleSection
                Divider()
                faceIDSection
                Divider()
                pillWingsSection
                Divider()
                modulesSection
                Divider()
                weatherSection
                Divider()
                creditsSection
            }
            .padding(20)
        }
        .frame(width: 580, height: 650)
        .onAppear {
            FaceEnrollmentStore.shared.reloadIfUnlocked()
            faceService.loadEnrolledFace()
        }
    }

    // MARK: - Subsections

    private var headerSection: some View {
        HStack(spacing: 12) {
            GlassyHaloLogoView(size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("OpenHalo Preferences")
                    .font(.system(size: 16, weight: .bold))

                Text("The Ultimate Native Dynamic Island & Glance Face ID for macOS")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    private var displayModeSection: some View {
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
    }

    private var systemLifecycleSection: some View {
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
    }

    private var faceIDSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Glance Face ID Engine & Screen Lock Assistant")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Text("Glance Architecture")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }

            HStack {
                Toggle("Enable Face ID Recognition on Lock Wake", isOn: Binding(
                    get: { faceService.isFaceAssistEnabled },
                    set: { enable in
                        if enable {
                            Task {
                                await faceService.requestEnableFaceAssist()
                            }
                        } else {
                            faceService.disableFaceAssist()
                        }
                    }
                ))
                .toggleStyle(.checkbox)
                .disabled(faceService.isVerifyingPermissions)

                if faceService.isVerifyingPermissions {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Pre-authorizing...")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                }
            }

            Text("Authentic Glance Face Recognition: Multi-angle 9-pose embedding, Core Image low-light adaptive contrast for dark/night rooms, and far/near distance support.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Mandatory Prerequisites Checklist
            VStack(alignment: .leading, spacing: 6) {
                Text("Mandatory Requirements for Lock-Screen Auto-Unlock:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.8))

                HStack(spacing: 12) {
                    // 1. Accessibility
                    HStack(spacing: 4) {
                        Image(systemName: faceService.isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(faceService.isAccessibilityGranted ? .green : .orange)
                        Text("1. Device Control (Accessibility)")
                            .font(.system(size: 9.5))
                            .foregroundColor(faceService.isAccessibilityGranted ? .white : Color.white.opacity(0.6))
                    }

                    // 2. Face Enrolled
                    HStack(spacing: 4) {
                        Image(systemName: faceService.hasEnrolledFace ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(faceService.hasEnrolledFace ? .green : .orange)
                        Text("2. Face Profile (9 Poses)")
                            .font(.system(size: 9.5))
                            .foregroundColor(faceService.hasEnrolledFace ? .white : Color.white.opacity(0.6))
                    }

                    // 3. Password
                    HStack(spacing: 4) {
                        Image(systemName: hasStoredPassword ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(hasStoredPassword ? .green : .orange)
                        Text("3. Login Password")
                            .font(.system(size: 9.5))
                            .foregroundColor(hasStoredPassword ? .white : Color.white.opacity(0.6))
                    }
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.04))
            .cornerRadius(6)

            // Enrolled Face Profiles (Multi-User Face ID)
            enrolledFacesSection

            // Keychain password box
            keychainPasswordBox

            // Advanced Glance Settings Disclosure
            glanceAdvancedSettingsDisclosure
        }
        .alert("Face ID Permission Required", isPresented: $faceService.isShowingPermissionAlert) {
            Button("OK", role: .cancel) {}
            if !faceService.isAccessibilityGranted {
                Button("Open Settings") {
                    faceService.openAccessibilitySettings()
                }
            } else if !faceService.hasEnrolledFace && FaceEnrollmentStore.shared.activeIdentities.isEmpty {
                Button("Enroll Face Now") {
                    faceService.launchGlanceGuidedNotchSweep()
                }
            }
        } message: {
            Text(faceService.permissionErrorMessage ?? "Please ensure all mandatory permissions are granted before enabling Face ID.")
        }
    }

    private var enrolledFacesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Enrolled Face Profiles (\(enrollmentStore.identities.count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    faceService.launchAddIdentity()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 11))
                        Text("Add Face...")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if enrollmentStore.identities.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.dashed")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No face profiles enrolled yet")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                        Text("Enroll your face or family members' faces with Glance guided 9-pose notch scanning.")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Enroll First Face") {
                        faceService.launchGlanceGuidedNotchSweep()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(6)
            } else {
                VStack(spacing: 6) {
                    ForEach(enrollmentStore.identities) { identity in
                        HStack(spacing: 10) {
                            Image(systemName: identity.isEnabled ? "person.crop.circle.fill" : "person.crop.circle")
                                .font(.system(size: 18))
                                .foregroundColor(identity.isEnabled ? .cyan : .secondary)

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text(identity.name)
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundColor(identity.isEnabled ? .white : .secondary)
                                    if !identity.isEnabled {
                                        Text("(Disabled)")
                                            .font(.system(size: 9))
                                            .foregroundColor(.orange)
                                    }
                                }
                                Text("\(identity.samples.count) poses • Added \(identity.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { identity.isEnabled },
                                set: { faceService.toggleIdentity(identity, isEnabled: $0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.mini)
                            .help("Enable or disable this face profile for auto-unlock")

                            Button(action: {
                                faceService.launchRecapture(for: identity)
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Recapture 9-pose samples for \(identity.name)")

                            Button(action: {
                                faceService.deleteIdentity(identity)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Remove \(identity.name)'s profile")
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(6)
                    }
                }

                HStack {
                    Text("• Multiple faces unlock the Mac in parallel against all active profiles.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear All Profiles") {
                        faceService.clearEnrolledFace()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundColor(.red.opacity(0.8))
                }
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(6)
    }

    private var keychainPasswordBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mac Auto-Unlock Login Password (Encrypted in Keychain):")
                .font(.system(size: 11, weight: .medium))

            HStack(spacing: 8) {
                SecureField(hasStoredPassword ? "•••••••••••• (Saved & Pre-Authorized)" : "Enter macOS User Password", text: $macPassword)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)

                Button("Save to Keychain") {
                    if !macPassword.isEmpty {
                        let entered = macPassword
                        macPassword = ""
                        if KeychainHelper.savePassword(entered) {
                            hasStoredPassword = true
                            passwordStatusMessage = "Encrypted in macOS Keychain & Cached"
                            // Immediately pre-authorize in foreground so macOS prompts now rather than at lock screen
                            Task {
                                _ = await KeychainHelper.getPasswordAsync(timeoutSeconds: 15.0)
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(macPassword.isEmpty)

                if hasStoredPassword {
                    Button("Remove") {
                        KeychainHelper.deletePassword()
                        hasStoredPassword = false
                        passwordStatusMessage = "Removed"
                        faceService.isFaceAssistEnabled = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(hasStoredPassword ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)

                Text(hasStoredPassword ? "Keychain: Encrypted & Ready for Auto-Unlock" : "Mandatory: Save password to allow Face ID to unlock at lock screen")
                    .font(.system(size: 10))
                    .foregroundColor(hasStoredPassword ? .secondary : .orange)

                if let msg = passwordStatusMessage {
                    Text("• \(msg)")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                }
            }

            Text("Important: When macOS displays the Keychain security dialog, choose 'Always Allow' so OpenHalo can unlock your Mac smoothly without hanging at the lock screen.")
                .font(.system(size: 9.5))
                .foregroundColor(Color.white.opacity(0.6))

            // Accessibility Status
            HStack(spacing: 8) {
                Circle()
                    .fill(faceService.isAccessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)

                Text(faceService.isAccessibilityGranted ? "Device Control & Keystrokes: Granted ✓" : "Device Control & Data Access: Required for Lock Screen")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(faceService.isAccessibilityGranted ? .green : .orange)

                if faceService.isAccessibilityGranted {
                    Text("(Ready for Lock Screen)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    Button("Open Settings") {
                        faceService.openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("Relaunch App") {
                        faceService.relaunchApp()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }

    private var glanceAdvancedSettingsDisclosure: some View {
        DisclosureGroup(isExpanded: $showAdvancedGlanceSettings) {
            VStack(alignment: .leading, spacing: 12) {
                // Match Sensitivity / Cosine Threshold
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Match Similarity Threshold:")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("\(Int(glanceSettings.matchThreshold * 100))% (Cosine Cutoff)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(glanceSettings.matchThreshold) },
                            set: { glanceSettings.matchThreshold = Float($0) }
                        ),
                        in: 0.50...0.85
                    )

                    HStack {
                        Text("Lenient (Better in Dark Rooms / Night)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Strict Security")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }

                // Distance Tolerance / Minimum Face Width
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Face Distance Prominence:")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("\(Int(glanceSettings.minimumFaceWidth * 100))% Width")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(glanceSettings.minimumFaceWidth) },
                            set: { glanceSettings.minimumFaceWidth = Float($0) }
                        ),
                        in: 0.06...0.25
                    )

                    HStack {
                        Text("Far Distance (2 - 3.5 ft)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Near Distance Only (1 ft)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }

                // Anti-Spoofing Liveness Checks
                HStack {
                    Toggle("Anti-Spoofing Liveness Verification", isOn: Binding(
                        get: { glanceSettings.livenessChecksEnabled },
                        set: { glanceSettings.livenessChecksEnabled = $0 }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11, weight: .medium))

                    Spacer()

                    Picker("Mode", selection: Binding(
                        get: { glanceSettings.livenessMode },
                        set: { glanceSettings.livenessMode = $0 }
                    )) {
                        Text("Light (Passive)").tag(LivenessMode.light)
                        Text("Heavy (Strict)").tag(LivenessMode.heavy)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                // Scan Window Timeout & Auto Retry
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Window: \(glanceSettings.faceDetectionSeconds)s")
                            .font(.system(size: 11, weight: .medium))
                        Slider(
                            value: Binding(
                                get: { Double(glanceSettings.faceDetectionSeconds) },
                                set: { glanceSettings.faceDetectionSeconds = Int($0) }
                            ),
                            in: 3...10,
                            step: 1
                        )
                        .frame(width: 140)
                    }

                    Toggle("Auto-Retry Once on Miss", isOn: Binding(
                        get: { glanceSettings.autoRetryOnce },
                        set: { glanceSettings.autoRetryOnce = $0 }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                }

                // Unlock Triggers
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock Triggers:")
                        .font(.system(size: 11, weight: .medium))

                    HStack(spacing: 16) {
                        triggerCheckbox(.onWake, label: "On Display Wake")
                        triggerCheckbox(.onLock, label: "On Screen Lock")
                        triggerCheckbox(.onSpace, label: "On Space Key")
                    }
                }

                // Unlock Animation Style & Auto-Lock Session
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notch Animation:")
                            .font(.system(size: 11, weight: .medium))

                        Picker("", selection: Binding(
                            get: { glanceSettings.unlockAnimationStyle },
                            set: { glanceSettings.unlockAnimationStyle = $0 }
                        )) {
                            Text("Minimal").tag(UnlockAnimationStyle.minimal)
                            Text("Original").tag(UnlockAnimationStyle.original)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-Lock Keychain Session:")
                            .font(.system(size: 11, weight: .medium))

                        Picker("", selection: Binding(
                            get: { glanceSettings.autoLockInterval },
                            set: { glanceSettings.autoLockInterval = $0 }
                        )) {
                            ForEach(AutoLockInterval.allCases) { interval in
                                Text(interval.title).tag(interval)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 130)
                    }
                }

                // Test Animation & Recommended Reset Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        coordinator.showFaceIDScan(isScanning: true, isUnlocked: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            SoundEffectManager.playActionBeep()
                            coordinator.showFaceIDScan(isScanning: false, isUnlocked: true)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "faceid")
                            Text("Test Face ID HUD")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {
                        glanceSettings.resetToRecommendedDefaults()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Recommended (68% / 10% Width)")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }
            .padding(10)
            .background(Color.white.opacity(0.02))
            .cornerRadius(8)
        } label: {
            Text("Glance Advanced Recognition & Hardware Parameters")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.cyan)
        }
    }

    private var pillWingsSection: some View {
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
    }

    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dynamic Island Modules")
                .font(.system(size: 12, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                Toggle("Now Playing Media", isOn: $coordinator.enableMediaModule)
                Toggle("Calendar & Meetings", isOn: $coordinator.enableCalendarModule)
                Toggle("Timers & Stopwatches", isOn: $coordinator.enableTimerModule)
                Toggle("Focus Notes & Tasks", isOn: $coordinator.enableFocusModule)
                Toggle("Weather & Forecast", isOn: $coordinator.enableWeatherModule)
                Toggle("Clipboard History", isOn: $coordinator.enableClipboardModule)
                Toggle("Quick App Launcher", isOn: $coordinator.enableLauncherModule)
                Toggle("Hardware Health", isOn: $coordinator.enableSystemModule)
                Toggle("File Drop Shelf", isOn: $coordinator.enableShelfModule)
                Toggle("Quick Camera Mirror", isOn: $coordinator.enableMirrorModule)
                Toggle("Microphone Indicator", isOn: $coordinator.enableMicIndicator)
                Toggle("MediaMate Volume HUD", isOn: $coordinator.enableHUDOverlay)
            }
            .toggleStyle(.checkbox)
            .font(.system(size: 11))
        }
    }

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weather Location")
                .font(.system(size: 12, weight: .semibold))

            HStack(spacing: 10) {
                TextField("City (e.g. San Francisco)", text: $weatherService.cityName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)

                Button("Refresh") {
                    Task {
                        await weatherService.fetchWeather(force: true)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Condition: \(weatherService.current?.conditionDescription ?? "Clear") • Temp: \(weatherService.current?.formattedTemp ?? "--")")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Credits & Architecture Attribution")
                .font(.system(size: 11, weight: .semibold))

            Text("OpenHalo brings together the greatest ideas in the macOS ecosystem:")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("• Glance by Jonathan Howard: On-device face recognition, Apple Vision & ArcFace embedding, anti-spoofing liveness verification, lock screen wake monitoring.")
                Text("• Atoll by Ebullioscopic: Dynamic Island fluid physics, tactile capsule sliders, and notch geometry.")
                Text("• MediaMate by Wouter Mac: macOS hardware HUD replacement.")
                Text("• Boring Notch by Harshil Shah: Notch detection & drop-down integration.")
            }
            .font(.system(size: 9))
            .foregroundColor(Color.white.opacity(0.6))
        }
    }

    private func triggerCheckbox(_ trigger: UnlockTrigger, label: String) -> some View {
        Toggle(
            label,
            isOn: Binding(
                get: { glanceSettings.unlockTriggers.contains(trigger) },
                set: { enabled in
                    var current = glanceSettings.unlockTriggers
                    if enabled {
                        current.insert(trigger)
                    } else if current.count > 1 {
                        current.remove(trigger)
                    }
                    glanceSettings.unlockTriggers = current
                }
            )
        )
        .toggleStyle(.checkbox)
        .font(.system(size: 10.5))
    }
}
