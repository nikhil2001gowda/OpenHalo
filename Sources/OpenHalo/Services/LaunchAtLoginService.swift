import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginService: ObservableObject {
    public static let shared = LaunchAtLoginService()

    @Published public private(set) var status: SMAppService.Status
    @Published public var isEnabled: Bool = false {
        didSet {
            guard isEnabled != (status == .enabled) else { return }
            toggleRegistration(enable: isEnabled)
        }
    }

    public init() {
        let currentStatus = SMAppService.mainApp.status
        self.status = currentStatus
        self.isEnabled = (currentStatus == .enabled)
    }

    public func refreshStatus() {
        self.status = SMAppService.mainApp.status
        self.isEnabled = (self.status == .enabled)
    }

    public func toggleRegistration(enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshStatus()
        } catch {
            refreshStatus()
        }
    }

    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
