import Foundation
import IOKit.ps

@MainActor
public final class BatteryService: ObservableObject {
    @Published public var batteryLevel: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var isPluggedIn: Bool = false
    @Published public var hasBattery: Bool = false

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
    }
}

