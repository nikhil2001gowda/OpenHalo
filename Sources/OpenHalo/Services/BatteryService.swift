import Foundation
import IOKit.ps
import IOKit

@MainActor
public final class BatteryService: ObservableObject {
    @Published public var batteryLevel: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var isPluggedIn: Bool = false
    @Published public var hasBattery: Bool = false
    @Published public var powerWatts: Double = 0.0
    @Published public var timeRemainingMinutes: Int = -1
    @Published public var consumptionRateText: String = "AC Power"
    @Published public var consumptionRateBadgeText: String = "AC Power"

    private var runLoopSource: CFRunLoopSource?

    public init() {
        updateBatteryState()
        registerPowerSourceNotification()
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    private func registerPowerSourceNotification() {
        let callback: IOPowerSourceCallbackType = { context in
            guard let context = context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                service.updateBatteryState()
            }
        }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            self.runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    public func updateBatteryState() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            self.hasBattery = false
            self.consumptionRateText = "Desktop AC Power"
            self.consumptionRateBadgeText = "AC Power"
            return
        }

        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                if let current = desc[kIOPSCurrentCapacityKey] as? Int,
                   let max = desc[kIOPSMaxCapacityKey] as? Int,
                   max > 0 {
                    self.batteryLevel = Int((Double(current) / Double(max)) * 100.0)
                    self.hasBattery = true
                }

                if let isCharging = desc[kIOPSIsChargingKey] as? Bool {
                    self.isCharging = isCharging
                }

                if let powerSourceState = desc[kIOPSPowerSourceStateKey] as? String {
                    self.isPluggedIn = (powerSourceState == kIOPSACPowerValue)
                }
                break
            }
        }

        updateSmartBatteryTelemetry()
    }

    private func updateSmartBatteryTelemetry() {
        guard hasBattery else { return }

        var service: io_service_t = 0
        if #available(macOS 12.0, *) {
            service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        } else {
            service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))
        }

        guard service != 0 else {
            if isCharging {
                self.consumptionRateText = "Charging"
                self.consumptionRateBadgeText = "Charging"
            } else if isPluggedIn {
                self.consumptionRateText = "Plugged In"
                self.consumptionRateBadgeText = "AC Power"
            } else {
                self.consumptionRateText = "Discharging"
                self.consumptionRateBadgeText = "On Battery"
            }
            return
        }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return
        }

        let voltage = (dict["Voltage"] as? Double) ?? (dict["AppleRawBatteryVoltage"] as? Double ?? 11400.0)

        // Read amperage: on discharge this is signed negative (in 64-bit/32-bit unsigned bitPattern)
        var signedAmperage: Double = 0.0
        if let rawNum = (dict["InstantAmperage"] as? NSNumber) ?? (dict["Amperage"] as? NSNumber) {
            let rawUInt = rawNum.uint64Value
            let val64 = Int64(bitPattern: rawUInt)
            if abs(val64) < 100_000 {
                signedAmperage = Double(val64)
            } else {
                let val32 = Int32(bitPattern: UInt32(truncatingIfNeeded: rawUInt))
                signedAmperage = Double(val32)
            }
        }

        // Calculate power draw in Watts = (mV * mA) / 1,000,000
        let watts = max(0.0, abs(signedAmperage * voltage) / 1_000_000.0)
        self.powerWatts = watts

        // Time to empty in minutes
        let timeRemaining = (dict["AvgTimeToEmpty"] as? Int) ?? (dict["TimeRemaining"] as? Int ?? -1)
        self.timeRemainingMinutes = (timeRemaining > 0 && timeRemaining < 65000) ? timeRemaining : -1

        let isCharging = (dict["IsCharging"] as? Bool) ?? self.isCharging

        if isCharging {
            let timeToFull = (dict["AvgTimeToFull"] as? Int) ?? -1
            if timeToFull > 0 && timeToFull < 65000 {
                let h = timeToFull / 60
                let m = timeToFull % 60
                self.consumptionRateText = String(format: "+%.1fW • %dh %02dm to full", watts, h, m)
                self.consumptionRateBadgeText = String(format: "+%.1fW Charging", watts)
            } else if watts > 0.1 {
                self.consumptionRateText = String(format: "+%.1fW Charging", watts)
                self.consumptionRateBadgeText = String(format: "+%.1fW", watts)
            } else {
                self.consumptionRateText = "Charging"
                self.consumptionRateBadgeText = "Charging"
            }
        } else if isPluggedIn {
            self.consumptionRateText = "Power Adapter"
            self.consumptionRateBadgeText = "AC Power"
        } else {
            // Discharging on battery
            if timeRemainingMinutes > 0 {
                let h = timeRemainingMinutes / 60
                let m = timeRemainingMinutes % 60
                if watts > 0.1 {
                    self.consumptionRateText = String(format: "%.1fW • %dh %02dm left", watts, h, m)
                    self.consumptionRateBadgeText = String(format: "%.1fW (%dh %02dm)", watts, h, m)
                } else {
                    self.consumptionRateText = String(format: "%dh %02dm left", h, m)
                    self.consumptionRateBadgeText = String(format: "%dh %02dm left", h, m)
                }
            } else if watts > 0.1 {
                self.consumptionRateText = String(format: "%.1fW Discharging", watts)
                self.consumptionRateBadgeText = String(format: "%.1fW", watts)
            } else {
                self.consumptionRateText = "Discharging"
                self.consumptionRateBadgeText = "Discharging"
            }
        }
    }
}

