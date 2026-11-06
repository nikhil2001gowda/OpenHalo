import SwiftUI

public struct SystemHealthView: View {
    @ObservedObject var hardwareMonitor: HardwareMonitorService
    @ObservedObject var batteryService: BatteryService
    @ObservedObject var audioMonitor: AudioActivityMonitor
    @ObservedObject var systemControls: SystemControlService

    @State private var copiedUUID = false
    @State private var formattedJSON = false

    @MainActor
    public init(
        hardwareMonitor: HardwareMonitorService,
        batteryService: BatteryService,
        audioMonitor: AudioActivityMonitor,
        systemControls: SystemControlService
    ) {
        self.hardwareMonitor = hardwareMonitor
        self.batteryService = batteryService
        self.audioMonitor = audioMonitor
        self.systemControls = systemControls
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Three Apple Sequoia-style hardware metric cards
            HStack(spacing: 10) {
                // CPU Metric Card
                modernMetricCard(
                    title: "CPU",
                    subtitle: "\(ProcessInfo.processInfo.activeProcessorCount) Cores",
                    value: String(format: "%.0f%%", hardwareMonitor.cpuUsagePercent),
                    progress: min(max(hardwareMonitor.cpuUsagePercent / 100.0, 0.03), 1.0),
                    icon: "cpu",
                    tint: cpuColor(hardwareMonitor.cpuUsagePercent)
                )

                // Memory Metric Card
                modernMetricCard(
                    title: "Memory",
                    subtitle: String(format: "%.1f GB Free", max(0, hardwareMonitor.totalMemoryGB - hardwareMonitor.usedMemoryGB)),
                    value: String(format: "%.1f GB", hardwareMonitor.usedMemoryGB),
                    progress: min(max(hardwareMonitor.memoryUsagePercent / 100.0, 0.03), 1.0),
                    icon: "memorychip",
                    tint: Color(red: 0.72, green: 0.42, blue: 0.98)
                )

                // Battery Metric Card
                modernMetricCard(
                    title: "Battery",
                    subtitle: batterySubtitle,
                    value: "\(batteryService.batteryLevel)%",
                    progress: min(max(Double(batteryService.batteryLevel) / 100.0, 0.03), 1.0),
                    icon: batteryIcon,
                    tint: batteryColor
                )
            }

            // Tactile Display Brightness Capsule Slider
            brightnessCapsuleSlider

            // Devly Quick Tools Bar
            quickToolsBar

            // Bottom Status & Security Line
            bottomStatusBar
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Modern Sequoia Activity-Ring Metric Card

    private func modernMetricCard(
        title: String,
        subtitle: String,
        value: String,
        progress: Double,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            // Circular Progress Ring
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: 3.5)
                    .frame(width: 38, height: 38)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [tint.opacity(0.7), tint]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.4), radius: 3, x: 0, y: 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.65))

                Text(subtitle)
                    .font(.system(size: 8.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Display Brightness Capsule Slider

    private var brightnessCapsuleSlider: some View {
        HStack(spacing: 9) {
            Image(systemName: "sun.min.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5 + Double(systemControls.brightness) * 0.4))

            GeometryReader { geo in
                let width = geo.size.width
                let clamped = min(max(Double(systemControls.brightness), 0.0), 1.0)
                let filledWidth = max(14, width * CGFloat(clamped))

                ZStack(alignment: .leading) {
                    // Track
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.12))

                    // Illuminated Fill
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.8, blue: 0.2),
                                    Color(red: 1.0, green: 0.65, blue: 0.1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: filledWidth)
                        .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 0)
                }
                .frame(height: 12)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let fraction = Double(gesture.location.x / width)
                            let newB = min(max(fraction, 0.0), 1.0)
                            systemControls.setBrightness(Float(newB))
                        }
                )
            }
            .frame(height: 12)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Devly Quick Tools Bar

    private var quickToolsBar: some View {
        HStack(spacing: 8) {
            // Stay Awake Toggle
            Button(action: {
                IslandCoordinator.shared.caffeinateService.toggleStayAwake(durationMinutes: 60)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: IslandCoordinator.shared.caffeinateService.isAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.system(size: 10))
                    Text(IslandCoordinator.shared.caffeinateService.isAwake ? "Awake (\(IslandCoordinator.shared.caffeinateService.remainingMinutes)m)" : "Stay Awake")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(IslandCoordinator.shared.caffeinateService.isAwake ? .black : Color.orange.opacity(0.95))
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    Capsule(style: .continuous)
                        .fill(IslandCoordinator.shared.caffeinateService.isAwake ? Color.orange : Color.orange.opacity(0.14))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.orange.opacity(0.25), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
            .pointingHandCursor()

            // Devly: UUID Generator
            Button(action: {
                let uuid = DeveloperToolsService.generateUUID()
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(uuid, forType: .string)
                copiedUUID = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    copiedUUID = false
                }
            }) {
                HStack(spacing: 3.5) {
                    Image(systemName: copiedUUID ? "checkmark" : "number")
                        .font(.system(size: 9.5, weight: .bold))
                    Text(copiedUUID ? "Copied!" : "UUID")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.cyan.opacity(copiedUUID ? 0.25 : 0.12))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.cyan.opacity(0.25), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help("Generate & copy UUID")

            // Devly: Format JSON
            Button(action: {
                if let clip = NSPasteboard.general.string(forType: .string) {
                    let formatted = DeveloperToolsService.formatJSON(clip)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(formatted, forType: .string)
                    formattedJSON = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        formattedJSON = false
                    }
                }
            }) {
                HStack(spacing: 3.5) {
                    Image(systemName: formattedJSON ? "checkmark" : "curlybraces")
                        .font(.system(size: 9.5, weight: .bold))
                    Text(formattedJSON ? "Formatted!" : "Format JSON")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.green.opacity(formattedJSON ? 0.25 : 0.12))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.green.opacity(0.25), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help("Format JSON from clipboard")

            // Preferences Access
            Button(action: {
                SettingsWindowManager.shared.show()
            }) {
                HStack(spacing: 3.5) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 9.5))
                    Text("Settings")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help("Open OpenHalo Preferences (⌘,)")

            Spacer()
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Bottom Status & Security Line

    private var bottomStatusBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(audioMonitor.isMicrophoneActive ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: (audioMonitor.isMicrophoneActive ? Color.orange : Color.green).opacity(0.6), radius: 2)

                Text(audioMonitor.isMicrophoneActive ? "Microphone In Use" : "Mic Idle • Encrypted & Secure")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.65))
            }

            Spacer()

            if batteryService.hasBattery {
                HStack(spacing: 4) {
                    if batteryService.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    }
                    Text(batteryService.isCharging ? "Charging" : (batteryService.isPluggedIn ? "Power Adapter" : "On Battery"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func cpuColor(_ percent: Double) -> Color {
        if percent > 80 { return .red }
        if percent > 50 { return .orange }
        return Color(red: 0.2, green: 0.8, blue: 0.95)
    }

    private var batteryIcon: String {
        if batteryService.isCharging {
            return "bolt.batteryblock.fill"
        }
        if batteryService.batteryLevel > 75 { return "battery.100" }
        if batteryService.batteryLevel > 40 { return "battery.75" }
        if batteryService.batteryLevel > 15 { return "battery.25" }
        return "battery.0"
    }

    private var batteryColor: Color {
        if batteryService.isCharging { return .green }
        if batteryService.batteryLevel <= 20 { return .red }
        return Color(red: 0.3, green: 0.85, blue: 0.4)
    }

    private var batterySubtitle: String {
        if batteryService.isCharging { return "Charging" }
        if batteryService.isPluggedIn { return "Plugged In" }
        return "Discharging"
    }
}
