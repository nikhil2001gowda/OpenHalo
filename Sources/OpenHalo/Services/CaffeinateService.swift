import Foundation
import IOKit.pwr_mgt

@MainActor
public final class CaffeinateService: ObservableObject {
    public static let shared = CaffeinateService()

    @Published public var isAwake: Bool = false
    @Published public var remainingMinutes: Int = 0

    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?

    public init() {}

    public func toggleStayAwake(durationMinutes: Int = 60) {
        if isAwake {
            deactivate()
        } else {
            activate(durationMinutes: durationMinutes)
        }
    }

    public func activate(durationMinutes: Int) {
        deactivate()

        var id: IOPMAssertionID = 0
        let reason = "OpenHalo Stay Awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &id
        )

        if result == kIOReturnSuccess {
            self.assertionID = id
            self.isAwake = true
            self.remainingMinutes = durationMinutes

            if durationMinutes > 0 {
                self.timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if self.remainingMinutes > 1 {
                            self.remainingMinutes -= 1
                        } else {
                            self.deactivate()
                        }
                    }
                }
            }
        }
    }

    public func deactivate() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        timer?.invalidate()
        timer = nil
        isAwake = false
        remainingMinutes = 0
    }
}
