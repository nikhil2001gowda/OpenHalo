import Foundation
@preconcurrency import AVFoundation
import Vision
import AppKit
import SwiftUI

public enum ScreenLockFaceState: Equatable, Sendable {
    case idle
    case waitingForLockWake
    case scanning(remainingSeconds: Double)
    case recognized(confidence: Float)
    case failed(reason: String)
    case timedOut
}

@MainActor
public final class ScreenLockFaceService: NSObject, ObservableObject {
    public static let shared = ScreenLockFaceService()

    @Published public var state: ScreenLockFaceState = .idle
    @Published public var isFaceAssistEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isFaceAssistEnabled, forKey: "OpenHalo.FaceID.Enabled")
            GlanceSettings.shared.isFaceUnlockEnabled = isFaceAssistEnabled
            GlanceCoordinator.shared.faceUnlockCoordinator.isEnabled = isFaceAssistEnabled
        }
    }
    @Published public var hasEnrolledFace: Bool = false
    @Published public var isAccessibilityGranted: Bool = KeystrokeInjector.isAccessibilityTrusted()
    @Published public var lastRecognitionTimestamp: Date? = nil
    @Published public var statusMessage: String = "Idle"

    // Interactive Enrollment Properties
    @Published public var isEnrolling: Bool = false
    @Published public var enrollmentProgress: Double = 0.0
    @Published public var enrollmentGuidance: String = "Position your face within the frame"
    @Published public var isEnrollmentComplete: Bool = false
    @Published public var detectedFaceInFrame: Bool = false
    @Published public var activeSession: AVCaptureSession? = nil

    private let enrollmentKey = "OpenHalo.FaceID.EnrolledSignature.v2"
    public private(set) var enrolledEmbedding: [Float] = []
    private var collectedEnrollmentEmbeddings: [[Float]] = []

    // Glance Camera & Processing
    private let cameraManager = CameraManager()
    private var framePollingTimer: Timer?
    private var isProcessingFrame = false
    private let embedder = VisionFeaturePrintEmbedder()

    public override init() {
        super.init()
        self.isFaceAssistEnabled = UserDefaults.standard.bool(forKey: "OpenHalo.FaceID.Enabled")
        loadEnrolledFace()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAccessibilityPermission()
        }

        // Keep Glance settings in sync
        GlanceSettings.shared.isFaceUnlockEnabled = self.isFaceAssistEnabled
    }

    public func checkAccessibilityPermission() {
        let trusted = KeystrokeInjector.isAccessibilityTrusted()
        if self.isAccessibilityGranted != trusted {
            self.isAccessibilityGranted = trusted
        }
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        KeystrokeInjector.promptForAccessibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    public func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, error in
            if error == nil {
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    // MARK: - Glance Interactive Enrollment

    public func startInteractiveEnrollment() {
        self.isEnrolling = true
        self.isEnrollmentComplete = false
        self.enrollmentProgress = 0.0
        self.enrollmentGuidance = "Position your face in the center"
        self.collectedEnrollmentEmbeddings = []
        self.detectedFaceInFrame = false

        Task {
            await self.cameraManager.start()
            self.activeSession = self.cameraManager.session
            self.startFramePolling()
        }
    }

    public func stopInteractiveEnrollment() {
        self.isEnrolling = false
        self.framePollingTimer?.invalidate()
        self.framePollingTimer = nil
        self.cameraManager.stop()
        self.activeSession = nil
    }

    public func stopAndCleanup() {
        stopInteractiveEnrollment()
    }

    private func startFramePolling() {
        framePollingTimer?.invalidate()
        framePollingTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let frame = self.cameraManager.currentFrame else { return }
                guard !self.isProcessingFrame else { return }
                self.isProcessingFrame = true
                await self.processCameraFrame(frame)
                self.isProcessingFrame = false
            }
        }
    }

    private func processCameraFrame(_ frame: CameraFrame) async {
        do {
            let faces = try FaceDetector.detectFaces(in: frame.image)
            guard let face = faces.first else {
                if isEnrolling {
                    self.detectedFaceInFrame = false
                }
                return
            }

            guard let crop = FaceDetector.crop(face, from: frame.image) else { return }

            if isEnrolling {
                self.detectedFaceInFrame = true
                let yaw = Double(face.yaw ?? 0)
                let pitch = Double(face.pitch ?? 0)
                await self.processEnrollmentStep(crop: crop, yaw: yaw, pitch: pitch)
            }
        } catch {
            // Frame processing retry
        }
    }

    private func processEnrollmentStep(crop: CGImage, yaw: Double, pitch: Double) async {
        guard isEnrolling && !isEnrollmentComplete else { return }

        if let embedding = try? embedder.embedding(for: crop) {
            collectedEnrollmentEmbeddings.append(embedding)
        }

        let current = enrollmentProgress

        if current < 0.3 {
            self.enrollmentGuidance = "Look directly at the camera"
            if abs(yaw) < 0.25 {
                enrollmentProgress = min(0.3, current + 0.05)
            }
        } else if current < 0.55 {
            self.enrollmentGuidance = "Slowly turn your head to the left"
            if yaw < -0.15 {
                enrollmentProgress = min(0.55, current + 0.05)
            } else {
                enrollmentProgress = min(0.55, current + 0.02)
            }
        } else if current < 0.8 {
            self.enrollmentGuidance = "Slowly turn your head to the right"
            if yaw > 0.15 {
                enrollmentProgress = min(0.8, current + 0.05)
            } else {
                enrollmentProgress = min(0.8, current + 0.02)
            }
        } else if current < 1.0 {
            self.enrollmentGuidance = "Tilt your head slightly up and down"
            if abs(pitch) > 0.08 {
                enrollmentProgress = min(1.0, current + 0.05)
            } else {
                enrollmentProgress = min(1.0, current + 0.02)
            }
        }

        if enrollmentProgress >= 1.0 {
            finishEnrollment()
        }
    }

    private func finishEnrollment() {
        self.isEnrollmentComplete = true
        self.enrollmentGuidance = "Face ID is Ready!"
        stopInteractiveEnrollment()

        if !collectedEnrollmentEmbeddings.isEmpty {
            if let avg = FaceEmbedding.average(collectedEnrollmentEmbeddings) {
                self.enrolledEmbedding = avg
            }
        } else {
            self.enrolledEmbedding = []
        }

        UserDefaults.standard.set(self.enrolledEmbedding, forKey: self.enrollmentKey)
        self.hasEnrolledFace = true
        self.statusMessage = "Face Profile Enrolled (Glance Engine)"

        // Reload FaceEnrollmentStore so FaceUnlockCoordinator immediately uses it
        FaceEnrollmentStore.shared.reloadIfUnlocked()

        SoundEffectManager.playActionBeep()
    }

    private func loadEnrolledFace() {
        if let stored = UserDefaults.standard.array(forKey: enrollmentKey) as? [Float], !stored.isEmpty {
            self.enrolledEmbedding = stored
            self.hasEnrolledFace = true
        }
    }

    public func clearEnrolledFace() {
        UserDefaults.standard.removeObject(forKey: enrollmentKey)
        self.enrolledEmbedding = []
        self.hasEnrolledFace = false
        self.statusMessage = "Face profile removed"
        FaceEnrollmentStore.shared.deleteAll()
    }

    public func enrollCurrentFace() {
        startInteractiveEnrollment()
    }
}
