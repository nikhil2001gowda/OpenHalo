import SwiftUI

public struct SystemHealthView: View {
    @ObservedObject var hardwareMonitor: HardwareMonitorService
    @ObservedObject var batteryService: BatteryService
    @ObservedObject var audioMonitor: AudioActivityMonitor
    @ObservedObject var systemControls: SystemControlService

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
            HStack(spacing: 14) {
                // CPU Metric
                metricCard(
                    title: "CPU",
                    value: String(format: "%.0f%%", hardwareMonitor.cpuUsagePercent),
                    progress: hardwareMonitor.cpuUsagePercent / 100.0,
                    icon: "cpu",
                    color: cpuColor(hardwareMonitor.cpuUsagePercent)
                )

                // RAM Metric
                metricCard(
                    title: "Memory",
                    value: String(format: "%.1f GB", hardwareMonitor.usedMemoryGB),
                    progress: hardwareMonitor.memoryUsagePercent / 100.0,
                    icon: "memorychip",
                    color: .purple
                )

                // Battery Metric
                metricCard(
                    title: "Battery",
                    value: "\(batteryService.batteryLevel)%",
                    progress: Double(batteryService.batteryLevel) / 100.0,
                    icon: batteryIcon,
                    color: batteryColor
                )
            }

            // Display Brightness Slider
            HStack(spacing: 10) {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.6))

                Slider(
                    value: Binding(
                        get: { systemControls.brightness },
                        set: { systemControls.setBrightness($0) }
                    ),
                    in: 0...1
                )

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 4)

            // Bottom Status Line
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(audioMonitor.isMicrophoneActive ? Color.orange : Color.green.opacity(0.8))
                        .frame(width: 7, height: 7)

                    Text(audioMonitor.isMicrophoneActive ? "Microphone Active" : "Mic Idle (Secure)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                }

                Spacer()

                if batteryService.hasBattery {
                    Text(batteryService.isCharging ? "Charging" : (batteryService.isPluggedIn ? "Power Adapter" : "On Battery"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func metricCard(
        title: String,
        value: String,
        progress: Double,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: 5) {
            ZStack {
                CircularProgressRing(
                    progress: progress,
                    lineWidth: 3.5,
                    primaryColor: color,
                    secondaryColor: Color.white.opacity(0.12)
                )
                .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func cpuColor(_ percent: Double) -> Color {
        if percent > 80 { return .red }
        if percent > 50 { return .orange }
        return .cyan
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
        return .green
    }
}
