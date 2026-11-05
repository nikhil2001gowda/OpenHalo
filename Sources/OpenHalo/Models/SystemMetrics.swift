import Foundation

public struct SystemMetrics: Equatable, Sendable {
    public var cpuUsagePercent: Double // 0.0 - 100.0
    public var memoryUsagePercent: Double // 0.0 - 100.0
    public var usedMemoryGB: Double
    public var totalMemoryGB: Double

    public var batteryLevel: Int // 0 - 100
    public var isCharging: Bool
    public var isPluggedIn: Bool
    public var hasBattery: Bool

    public init(
        cpuUsagePercent: Double = 0.0,
        memoryUsagePercent: Double = 0.0,
        usedMemoryGB: Double = 0.0,
        totalMemoryGB: Double = 0.0,
        batteryLevel: Int = 100,
        isCharging: Bool = false,
        isPluggedIn: Bool = false,
        hasBattery: Bool = false
    ) {
        self.cpuUsagePercent = cpuUsagePercent
        self.memoryUsagePercent = memoryUsagePercent
        self.usedMemoryGB = usedMemoryGB
        self.totalMemoryGB = totalMemoryGB
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.hasBattery = hasBattery
    }
}
