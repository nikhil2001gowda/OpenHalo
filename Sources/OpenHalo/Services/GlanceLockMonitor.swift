import Foundation
import AppKit
import CoreGraphics

public enum GlanceLockEventKind: Sendable {
    case screenLocked
    case screenUnlocked
    case willSleep
    case wake
}

@MainActor
public final class GlanceLockMonitor: ObservableObject {
    public static let shared = GlanceLockMonitor()

    @Published public private(set) var isScreenLocked: Bool = false
    @Published public private(set) var isSleeping: Bool = false
    @Published public private(set) var lastEvent: GlanceLockEventKind?

    public var onLockStateChanged: (@MainActor (GlanceLockEventKind) -> Void)?

    private var distributedObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    public init() {
        startMonitoring()
    }

    deinit {
        let distributed = DistributedNotificationCenter.default()
        for observer in distributedObservers {
            distributed.removeObserver(observer)
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            workspace.removeObserver(observer)
        }
    }

    private func startMonitoring() {
        let distributed = DistributedNotificationCenter.default()

        distributedObservers.append(distributed.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isScreenLocked = true
                self.lastEvent = .screenLocked
                self.onLockStateChanged?(.screenLocked)
            }
        })

        distributedObservers.append(distributed.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isScreenLocked = false
                self.lastEvent = .screenUnlocked
                self.onLockStateChanged?(.screenUnlocked)
            }
        })

        distributedObservers.append(distributed.addObserver(
            forName: Notification.Name("com.apple.screensaver.didstop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recordWake()
            }
        })

        let workspace = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isSleeping = true
                self.lastEvent = .willSleep
                self.onLockStateChanged?(.willSleep)
            }
        })

        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recordWake()
            }
        })

        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recordWake()
            }
        })
    }

    private func recordWake() {
        isSleeping = false
        lastEvent = .wake
        onLockStateChanged?(.wake)
    }

    /// Authoritative lock state from the CoreGraphics session server.
    public nonisolated static func isScreenActuallyLocked() -> Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        return (dict["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }
}
