import Foundation
import Observation

@Observable
@MainActor
public final class GlanceCoordinator {
    public static let shared = GlanceCoordinator()

    let pocController: POCController
    let faceUnlockCoordinator: FaceUnlockCoordinator
    let sessionAutoLocker: SessionAutoLocker

    init() {
        let poc = POCController()
        self.pocController = poc
        self.faceUnlockCoordinator = FaceUnlockCoordinator(pocController: poc)
        self.sessionAutoLocker = SessionAutoLocker(pocController: poc)
    }

    public func start() {
        // FaceUnlockCoordinator observes lock/wake events continuously
        _ = faceUnlockCoordinator
    }
}
