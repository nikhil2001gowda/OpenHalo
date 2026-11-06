import Foundation
import AppKit
import Combine

@MainActor
public final class PowerSuspensionCoordinator: ObservableObject {
    public static let shared = PowerSuspensionCoordinator()

    @Published public private(set) var isSuspended: Bool = false
    @Published public private(set) var sleepCount: Int = 0
    @Published public private(set) var wakeCount: Int = 0

    private var observers: [NSObjectProtocol] = []

    public init() {
        registerObservers()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    public func registerObservers() {
        let center = NSWorkspace.shared.notificationCenter

        let s1 = center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.enterDeepSleepSuspension()
            }
        }

        let s2 = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.enterDeepSleepSuspension()
            }
        }

        let w1 = center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeFromDeepSleep()
            }
        }

        let w2 = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeFromDeepSleep()
            }
        }

        observers = [s1, s2, w1, w2]
    }

    public func enterDeepSleepSuspension() {
        guard !isSuspended else { return }
        isSuspended = true
        sleepCount += 1

        let coordinator = IslandCoordinator.shared
        coordinator.hardwareMonitor.stopPolling()
        coordinator.audioMonitor.stopMonitoring()
        coordinator.systemControls.stopHardwareVolumeListener()
        coordinator.clipboardService.stopMonitoring()
        coordinator.presenceService.stopAndCleanup()
        coordinator.mirrorService.stopSession()
    }

    public func resumeFromDeepSleep() {
        guard isSuspended else { return }
        isSuspended = false
        wakeCount += 1

        let coordinator = IslandCoordinator.shared
        // hardwareMonitor only polls on-demand when user is viewing .system tab
        coordinator.audioMonitor.startMonitoring()
        coordinator.systemControls.startHardwareVolumeListener()
        coordinator.clipboardService.startMonitoring()
        coordinator.weatherService.refreshIfStale()
    }
}
