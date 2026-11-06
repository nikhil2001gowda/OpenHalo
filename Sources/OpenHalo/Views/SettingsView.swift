import SwiftUI
import ServiceManagement

public enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case faceID = "Face ID & Unlock"
    case security = "Security & Liveness"
    case dynamicIsland = "Dynamic Island"
    case pillWings = "Pill Wings & Slots"
    case about = "About OpenHalo"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .faceID: return "faceid"
        case .security: return "shield.checkerboard"
        case .dynamicIsland: return "sparkles"
        case .pillWings: return "slider.horizontal.2.square"
        case .about: return "info.circle.fill"
        }
    }

    var gradient: [Color] {
        switch self {
        case .general: return [Color.blue, Color(red: 0.1, green: 0.6, blue: 0.9)]
        case .faceID: return [Color(red: 0.1, green: 0.8, blue: 0.4), Color.mint]
        case .security: return [Color(red: 0.35, green: 0.3, blue: 0.9), Color.purple]
        case .dynamicIsland: return [Color(red: 0.85, green: 0.2, blue: 0.7), Color.pink]
        case .pillWings: return [Color.orange, Color(red: 1.0, green: 0.7, blue: 0.2)]
        case .about: return [Color(red: 0.2, green: 0.7, blue: 0.8), Color.blue]
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var coordinator = IslandCoordinator.shared
    @ObservedObject var loginService = LaunchAtLoginService.shared
    @ObservedObject var faceService = ScreenLockFaceService.shared
    @ObservedObject var powerCoordinator = PowerSuspensionCoordinator.shared
    @ObservedObject var weatherService = WeatherService.shared

    @State private var glanceSettings = GlanceSettings.shared
    @State private var enrollmentStore = FaceEnrollmentStore.shared
    @State private var selectedCategory: SettingsCategory = .general

    @State private var macPassword: String = ""
    @State private var hasStoredPassword: Bool = KeychainHelper.hasPassword()
    @State private var passwordStatusMessage: String? = nil

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - iOS / macOS System Settings Sidebar
            sidebarView
                .frame(width: 230)
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))

            Divider()
                .opacity(0.3)

            // MARK: - Detail Content Pane
            ZStack {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        detailHeader

                        switch selectedCategory {
                        case .general:
                            generalSection
                        case .faceID:
                            faceIDSection
                        case .security:
                            securitySection
                        case .dynamicIsland:
                            dynamicIslandSection
                        case .pillWings:
                            pillWingsSection
                        case .about:
                            aboutSection
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                    .frame(maxWidth: 680, alignment: .leading)
                }
            }
            .frame(minWidth: 530, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            FaceEnrollmentStore.shared.reloadIfUnlocked()
            faceService.loadEnrolledFace()
            coordinator.hardwareMonitor.startPolling(interval: 1.5)
            coordinator.batteryService.updateBatteryState()
        }
        .onDisappear {
            coordinator.hardwareMonitor.stopPolling()
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

    // MARK: - Sidebar View

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Top App Brand
            HStack(spacing: 10) {
                GlassyHaloLogoView(size: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("OpenHalo")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Settings")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 16)

            // Navigation List
            VStack(spacing: 3) {
                ForEach(SettingsCategory.allCases) { category in
                    sidebarItem(for: category)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // Sleep & Power preservation badge
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Low-Power Engine")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                        Text("• Active")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.green)
                    }
                    Text("\(String(format: "%.1f%%", coordinator.hardwareMonitor.appCPUUsagePercent)) CPU • \(coordinator.batteryService.consumptionRateBadgeText)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }

    private func sidebarItem(for category: SettingsCategory) -> some View {
        let isSelected = selectedCategory == category

        return SidebarItemButton(
            category: category,
            isSelected: isSelected,
            showFaceIDDot: (category == .faceID && faceService.isFaceAssistEnabled),
            action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedCategory = category
                }
            }
        )
    }

    // MARK: - Detail Header

    private var detailHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: selectedCategory.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: selectedCategory.gradient.first?.opacity(0.3) ?? .clear, radius: 3, y: 1.5)

                Image(systemName: selectedCategory.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedCategory.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(subtitleForCategory(selectedCategory))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.bottom, 6)
    }

    private func subtitleForCategory(_ category: SettingsCategory) -> String {
        switch category {
        case .general: return "Configure display anchoring, launch behavior, and system lifecycle."
        case .faceID: return "Glance multi-profile biometric screen lock auto-unlock and animation."
        case .security: return "Anti-spoofing verification, cosine distance threshold, and session locks."
        case .dynamicIsland: return "Manage live activities, mini-apps, and weather location."
        case .pillWings: return "Customize idle pill status indicators and audio waveforms."
        case .about: return "Architecture attributions and open-source macOS credits."
        }
    }

    // MARK: - Section 1: General

    private var generalSection: some View {
        VStack(spacing: 16) {
            // Display Mode
            SettingsGroup(title: "Display Mode") {
                VStack(spacing: 10) {
                    ForEach(IslandDisplayMode.allCases) { mode in
                        displayModeOption(mode)
                    }
                }
                .padding(12)
            }

            // Launch & Lifecycle
            SettingsGroup(title: "System Lifecycle & Startup") {
                VStack(spacing: 0) {
                    SettingsRow(
                        title: "Launch OpenHalo at Login",
                        subtitle: "Registers OpenHalo with macOS SMAppService to start cleanly on boot",
                        icon: "power",
                        iconColor: .blue
                    ) {
                        Toggle("", isOn: $loginService.isEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider()
                        .padding(.leading, 42)

                    SettingsRow(
                        title: "Glance Low-Power Engine",
                        subtitle: "Suspends all camera, Mach timers, and hardware loops when display sleeps",
                        icon: "bolt.badge.clock.fill",
                        iconColor: .green
                    ) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text(powerCoordinator.sleepStateDescription)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
    }

    private func displayModeOption(_ mode: IslandDisplayMode) -> some View {
        let isSelected = coordinator.displayMode == mode

        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                coordinator.displayMode = mode
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .cyan : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    Text(displayModeDescription(mode))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.cyan.opacity(0.08) : Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.cyan.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func displayModeDescription(_ mode: IslandDisplayMode) -> String {
        switch mode {
        case .autoDetect: return "Adapts automatically: hugs hardware notch on notched MacBooks, floats on external screens."
        case .forceFloating: return "Floats as a free-standing rounded dynamic pill beneath the menu bar on all displays."
        case .forceNotch: return "Always snaps flush against the physical top bezel and menu bar edge."
        }
    }

    // MARK: - Section 2: Face ID & Unlock

    private var faceIDSection: some View {
        VStack(spacing: 16) {
            // Master Switch & Checklist
            SettingsGroup(title: "Biometric Auto-Unlock") {
                VStack(spacing: 12) {
                    SettingsRow(
                        title: "Enable Face ID Recognition on Lock Wake",
                        subtitle: "Automatically scans face and logs in to macOS upon display wake or key press",
                        icon: "faceid",
                        iconColor: .green
                    ) {
                        HStack(spacing: 8) {
                            if faceService.isVerifyingPermissions {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                            Toggle("", isOn: Binding(
                                get: { faceService.isFaceAssistEnabled },
                                set: { enable in
                                    if enable {
                                        Task { await faceService.requestEnableFaceAssist() }
                                    } else {
                                        faceService.disableFaceAssist()
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(faceService.isVerifyingPermissions)
                        }
                    }

                    // Mandatory Checklist Cards
                    HStack(spacing: 8) {
                        requirementPill(
                            title: "Device Control",
                            isMet: faceService.isAccessibilityGranted,
                            icon: "keyboard"
                        )
                        requirementPill(
                            title: "Face Profile (9 Poses)",
                            isMet: faceService.hasEnrolledFace,
                            icon: "person.crop.circle"
                        )
                        requirementPill(
                            title: "Keychain Password",
                            isMet: hasStoredPassword,
                            icon: "key.fill"
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
            }

            // Enrolled Face Profiles (Multi-User)
            SettingsGroup(title: "Enrolled Face Profiles (\(enrollmentStore.identities.count))") {
                VStack(spacing: 10) {
                    HStack {
                        Text("Multi-User Face Profiles")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { faceService.launchAddIdentity() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add Face...")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                    if enrollmentStore.identities.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("No Face Enrolled Yet")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Scan your face with Glance 9-pose guided notch enrollment to unlock your Mac.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Enroll Face") {
                                faceService.launchGlanceGuidedNotchSweep()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(8)
                        .padding(.horizontal, 12)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(enrollmentStore.identities) { identity in
                                faceProfileRow(identity)
                            }
                        }
                        .padding(.horizontal, 12)

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
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
            }

            // Keychain Password Card
            SettingsGroup(title: "Mac Auto-Unlock Login Password (Encrypted in Keychain)") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        SecureField(hasStoredPassword ? "•••••••••••• (Saved & Pre-Authorized)" : "Enter macOS User Password", text: $macPassword)
                            .textFieldStyle(.roundedBorder)

                        Button("Save to Keychain") {
                            if !macPassword.isEmpty {
                                let entered = macPassword
                                macPassword = ""
                                if KeychainHelper.savePassword(entered) {
                                    hasStoredPassword = true
                                    passwordStatusMessage = "Encrypted in macOS Keychain & Cached"
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

                    Text("OpenHalo securely injects keystrokes via macOS Accessibility to unlock the screen. Your password never leaves local device-encrypted keychain storage.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
                .padding(12)
            }

            // Unlock Triggers & Animation Style
            SettingsGroup(title: "Unlock Triggers & Notch Animation") {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        triggerToggle(.onWake, label: "On Display Wake")
                        triggerToggle(.onLock, label: "On Screen Lock")
                        triggerToggle(.onSpace, label: "On Space Key")
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                    Divider()
                        .padding(.horizontal, 12)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notch Animation Style:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)

                            Picker("", selection: Binding(
                                get: { glanceSettings.unlockAnimationStyle },
                                set: { glanceSettings.unlockAnimationStyle = $0 }
                            )) {
                                Text("Minimal").tag(UnlockAnimationStyle.minimal)
                                Text("Original").tag(UnlockAnimationStyle.original)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button(action: {
                                let style = glanceSettings.effectiveUnlockAnimationStyle
                                NotchOverlayController.shared.present(styleOverride: style)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    SoundEffectManager.playActionBeep()
                                    NotchOverlayController.shared.finish(success: true)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("Test Notch Animation")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }
        }
    }

    private func requirementPill(title: String, isMet: Bool, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isMet ? .green : .orange)
                .font(.system(size: 11))

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isMet ? .white : Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isMet ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isMet ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 0.8)
        )
    }

    private func faceProfileRow(_ identity: FaceIdentity) -> some View {
        HStack(spacing: 10) {
            Image(systemName: identity.isEnabled ? "person.crop.circle.fill" : "person.crop.circle")
                .font(.system(size: 20))
                .foregroundColor(identity.isEnabled ? .cyan : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(identity.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(identity.isEnabled ? .white : .secondary)

                    if !identity.isEnabled {
                        Text("(Disabled)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
                Text("\(identity.samples.count) poses • Added \(identity.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10))
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

            Button(action: { faceService.launchRecapture(for: identity) }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Recapture 9-pose samples for \(identity.name)")

            Button(action: { faceService.deleteIdentity(identity) }) {
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

    private func triggerToggle(_ trigger: UnlockTrigger, label: String) -> some View {
        let isChecked = glanceSettings.unlockTriggers.contains(trigger)

        return Button(action: {
            var current = glanceSettings.unlockTriggers
            if isChecked {
                if current.count > 1 { current.remove(trigger) }
            } else {
                current.insert(trigger)
            }
            glanceSettings.unlockTriggers = current
        }) {
            HStack(spacing: 6) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12))
                    .foregroundColor(isChecked ? .cyan : .secondary)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isChecked ? .white : Color.white.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 3: Security & Liveness

    private var securitySection: some View {
        VStack(spacing: 16) {
            // Anti-Spoofing Liveness
            SettingsGroup(title: "Anti-Spoofing & Liveness Detection") {
                VStack(spacing: 0) {
                    SettingsRow(
                        title: "Liveness Verification",
                        subtitle: "Detects 3D facial depth, natural micro-movements, and screens/photos",
                        icon: "shield.lefthalf.filled",
                        iconColor: .indigo
                    ) {
                        Toggle("", isOn: Binding(
                            get: { glanceSettings.livenessChecksEnabled },
                            set: { glanceSettings.livenessChecksEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    Divider()
                        .padding(.leading, 52)

                    SettingsRow(
                        title: "Liveness Strictness Mode",
                        subtitle: "Light balances fast unlock; Heavy runs deep spatial frequency analysis",
                        icon: "waveform.path.ecg",
                        iconColor: .purple
                    ) {
                        Picker("", selection: Binding(
                            get: { glanceSettings.livenessMode },
                            set: { glanceSettings.livenessMode = $0 }
                        )) {
                            Text("Light (Passive)").tag(LivenessMode.light)
                            Text("Heavy (Strict)").tag(LivenessMode.heavy)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 230)
                    }
                }
            }

            // Facial Match & Distance Sliders
            SettingsGroup(title: "Recognition Parameters") {
                VStack(spacing: 0) {
                    // Match Similarity Threshold
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Match Similarity Threshold")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(glanceSettings.matchThreshold * 100))% (Cosine Cutoff)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.12))
                                .cornerRadius(4)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(glanceSettings.matchThreshold) },
                                set: { glanceSettings.matchThreshold = Float($0) }
                            ),
                            in: 0.50...0.85
                        )

                        HStack {
                            Text("Lenient (Better in Dark Rooms)")
                            Spacer()
                            Text("Strict Security")
                        }
                        .font(.system(size: 9.5))
                        .foregroundColor(Color.white.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()
                        .padding(.horizontal, 14)

                    // Face Distance Prominence
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Face Distance Prominence")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(glanceSettings.minimumFaceWidth * 100))% Width")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.12))
                                .cornerRadius(4)
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
                            Spacer()
                            Text("Near Distance Only (1 ft)")
                        }
                        .font(.system(size: 9.5))
                        .foregroundColor(Color.white.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()
                        .padding(.horizontal, 14)

                    // Scan Window Timeout
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Scan Window Timeout")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(glanceSettings.faceDetectionSeconds)s")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.12))
                                .cornerRadius(4)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(glanceSettings.faceDetectionSeconds) },
                                set: { glanceSettings.faceDetectionSeconds = Int($0) }
                            ),
                            in: 3...10,
                            step: 1
                        )

                        HStack {
                            Text("3 seconds (Fastest)")
                            Spacer()
                            Text("10 seconds (Thorough)")
                        }
                        .font(.system(size: 9.5))
                        .foregroundColor(Color.white.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()
                        .padding(.horizontal, 14)

                    // Auto-Retry on Miss
                    SettingsRow(
                        title: "Auto-Retry Once on Miss",
                        subtitle: "Attempts a second rapid scan if the first pass does not find a match",
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .teal
                    ) {
                        Toggle("", isOn: Binding(
                            get: { glanceSettings.autoRetryOnce },
                            set: { glanceSettings.autoRetryOnce = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    Divider()
                        .padding(.leading, 52)

                    // Auto-Lock Keychain Session
                    SettingsRow(
                        title: "Auto-Lock Keychain Session",
                        subtitle: "Wipes in-memory decrypted session credentials after idle timeout",
                        icon: "lock.shield",
                        iconColor: .orange
                    ) {
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
            }

            // Reset Defaults Button
            HStack {
                Spacer()
                Button(action: {
                    glanceSettings.resetToRecommendedDefaults()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Security Defaults")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Section 4: Dynamic Island & Modules

    private var dynamicIslandSection: some View {
        VStack(spacing: 16) {
            // Modules Grid with Colorful Icons
            SettingsGroup(title: "Active Modules & Live Activities") {
                VStack(spacing: 0) {
                    moduleRow("Now Playing Media", subtitle: "Music playback controls, album art, audio scrubbing", icon: "music.note", color: .pink, binding: $coordinator.enableMediaModule)
                    Divider().padding(.leading, 42)
                    moduleRow("Calendar & Meetings", subtitle: "Upcoming schedule, 1-click Zoom/Meet launch", icon: "calendar", color: .red, binding: $coordinator.enableCalendarModule)
                    Divider().padding(.leading, 42)
                    moduleRow("Timers & Stopwatches", subtitle: "Live countdowns and stopwatch progress bar", icon: "timer", color: .orange, binding: $coordinator.enableTimerModule)
                    Divider().padding(.leading, 42)
                    moduleRow("Focus Notes & Tasks", subtitle: "Quick Markdown task checklist and scratchpad", icon: "checklist", color: .yellow, binding: $coordinator.enableFocusModule)
                    Divider().padding(.leading, 42)
                    moduleRow("Weather & Forecast", subtitle: "Real-time conditions, temperature, precipitation", icon: "cloud.sun.fill", color: .cyan, binding: $coordinator.enableWeatherModule)
                    Divider().padding(.leading, 42)
                    moduleRow("Clipboard History", subtitle: "Multi-item clipboard manager with search and previews", icon: "doc.on.clipboard.fill", color: .blue, binding: $coordinator.enableClipboardModule)
                    Divider().padding(.leading, 42)
                    moduleRow("Quick App Launcher", subtitle: "Pin frequently used macOS apps for 1-click launch", icon: "square.grid.2x2.fill", color: .indigo, binding: $coordinator.enableLauncherModule)
                    Divider().padding(.leading, 42)
                    moduleRow("Hardware Health", subtitle: "CPU load, RAM consumption, and battery telemetry", icon: "gauge.with.needle.fill", color: .green, binding: $coordinator.enableSystemModule)
                    Divider().padding(.leading, 42)
                    moduleRow("File Drop Shelf", subtitle: "Drag files to notch to stash, AirDrop, or convert", icon: "tray.and.arrow.down.fill", color: .teal, binding: $coordinator.enableShelfModule)
                    Divider().padding(.leading, 42)
                    moduleRow("Quick Camera Mirror", subtitle: "Live camera vanity check before video calls", icon: "camera.fill", color: .purple, binding: $coordinator.enableMirrorModule)
                    Divider().padding(.leading, 42)
                    moduleRow("Microphone Indicator", subtitle: "Shows green/orange dot when microphone is in use", icon: "mic.fill", color: .orange, binding: $coordinator.enableMicIndicator)
                    Divider().padding(.leading, 42)
                    moduleRow("MediaMate Volume HUD", subtitle: "Replaces macOS volume/brightness HUD with notch HUD", icon: "speaker.wave.3.fill", color: .blue, binding: $coordinator.enableHUDOverlay)
                }
            }

            // Weather Location
            SettingsGroup(title: "Weather Service Location") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        TextField("City (e.g. Bengaluru, San Francisco)", text: $weatherService.cityName)
                            .textFieldStyle(.roundedBorder)

                        Button("Refresh") {
                            Task { await weatherService.fetchWeather(force: true) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)

                        Text("Current: \(weatherService.current?.conditionDescription ?? "Clear") • \(weatherService.current?.formattedTemp ?? "--")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .padding(12)
            }
        }
    }

    private func moduleRow(_ title: String, subtitle: String, icon: String, color: Color, binding: Binding<Bool>) -> some View {
        SettingsRow(title: title, subtitle: subtitle, icon: icon, iconColor: color) {
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    // MARK: - Section 5: Pill Wings & Slots

    private var pillWingsSection: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: "Compact Pill Idle Slots") {
                VStack(spacing: 14) {
                    Text("Configure what is shown in the left and right ears when the island is collapsed:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Left Wing Slot")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.white)

                            Picker("", selection: $coordinator.leadingSlot) {
                                ForEach(PillLeadingSlot.allCases) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Right Wing Slot")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.white)

                            Picker("", selection: $coordinator.trailingSlot) {
                                ForEach(PillTrailingSlot.allCases) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(12)
            }

            // Interactive Live Preview
            SettingsGroup(title: "Pill Preview") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Interactive Compact Pill Demonstration:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Toggle Expanded Island") {
                            coordinator.toggleExpanded()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: - Section 6: About & Credits

    private var aboutSection: some View {
        VStack(spacing: 16) {
            // Hero App Identity
            VStack(spacing: 8) {
                GlassyHaloLogoView(size: 56)

                Text("OpenHalo")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Version 4.0.0 (Build 4)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Text("The Ultimate Native Dynamic Island & Glance Face ID for macOS")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            )

            // Architecture Attribution Cards
            SettingsGroup(title: "Architecture & Open-Source Attribution") {
                VStack(spacing: 8) {
                    attributionCard(
                        title: "Glance by Jonathan Howard",
                        description: "On-device face recognition, Apple Vision & ArcFace embedding, anti-spoofing liveness verification, lock screen wake monitoring."
                    )
                    attributionCard(
                        title: "Atoll by Ebullioscopic",
                        description: "Dynamic Island fluid physics, tactile capsule sliders, and notch geometry."
                    )
                    attributionCard(
                        title: "MediaMate by Wouter Mac",
                        description: "macOS hardware volume and brightness HUD replacement."
                    )
                    attributionCard(
                        title: "Boring Notch by Harshil Shah",
                        description: "Hardware notch detection & drop-down integration."
                    )
                }
                .padding(12)
            }
        }
    }

    private func attributionCard(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.cyan)
            Text(description)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(6)
    }
}

// MARK: - Full-Card Interactive Sidebar Button

struct SidebarItemButton: View {
    let category: SettingsCategory
    let isSelected: Bool
    let showFaceIDDot: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Squircle Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: category.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                        .shadow(color: category.gradient.first?.opacity(0.25) ?? .clear, radius: 2, y: 1)

                    Image(systemName: category.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(category.rawValue)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.85))

                Spacer(minLength: 0)

                if showFaceIDDot {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.85)
                            : (isHovered ? Color.white.opacity(0.08) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.2) : Color.clear,
                        lineWidth: 0.8
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .pointingHandCursor()
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Reusable UI Components

/// Glassy, rounded inset grouped card matching modern macOS System Settings
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
            )
        }
    }
}

/// Standardized iOS/macOS settings row with colorful squircle icon, title, subtitle, and right-aligned control
struct SettingsRow<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            if let icon, let iconColor {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 26, height: 26)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(iconColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.55))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 16)

            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Native macOS AppKit Visual Effect View for vibrant translucent blur
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
