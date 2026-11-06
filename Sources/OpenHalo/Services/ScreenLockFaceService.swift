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

    // Interactive 9-Pose Enrollment Properties (Glance Engine)
    @Published public var isEnrolling: Bool = false
    @Published public var enrollmentProgress: Double = 0.0
    @Published public var enrollmentGuidance: String = "Position your face within the frame"
    @Published public var isEnrollmentComplete: Bool = false
    @Published public var detectedFaceInFrame: Bool = false
    @Published public var isHoldingPose: Bool = false
    @Published public var activeSession: AVCaptureSession? = nil
    @Published public var currentPoseIndex: Int = 0

    private let enrollmentKey = "OpenHalo.FaceID.EnrolledSignature.v2"
    public private(set) var enrolledEmbedding: [Float] = []
    private var collectedSamples: [FaceSample] = []

    // Glance Camera & Recognition Pipeline
    private let cameraManager = CameraManager()
    private var framePollingTimer: Timer?
    private var isProcessingFrame = false
    private let pipeline = FaceRecognitionPipeline()

    // 9 Guided Compass Poses (Glance Enrollment Engine)
    let poses = EnrollmentPose.allCases
    private let samplesPerPose = 2
    private var capturedForCurrentPose = 0
    private var matchStreak = 0
    private let requiredMatchStreak = 3
    private var poseHoldStartedAt: Date?
    private let poseHoldDuration: TimeInterval = 0.50

    public override init() {
        super.init()
        self.isFaceAssistEnabled = UserDefaults.standard.bool(forKey: "OpenHalo.FaceID.Enabled")
        loadEnrolledFace()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAccessibilityPermission()
            }
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

    // MARK: - Glance Canonical Guided 9-Pose Enrollment

    public func launchGlanceGuidedNotchSweep() {
        OnboardingController.startEnrollmentOnly()
    }

    public func startInteractiveEnrollment() {
        self.isEnrolling = true
        self.isEnrollmentComplete = false
        self.enrollmentProgress = 0.0
        self.currentPoseIndex = 0
        self.capturedForCurrentPose = 0
        self.matchStreak = 0
        self.poseHoldStartedAt = nil
        self.isHoldingPose = false
        self.enrollmentGuidance = poses[0].instruction
        self.collectedSamples = []
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
        self.isHoldingPose = false
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
        guard isEnrolling && !isEnrollmentComplete else { return }

        do {
            let faces = try FaceDetector.detectFaces(in: frame.image)
            guard let face = FaceRecognitionPipeline.largestFace(in: faces) else {
                self.detectedFaceInFrame = false
                self.matchStreak = 0
                self.poseHoldStartedAt = nil
                self.isHoldingPose = false
                return
            }

            self.detectedFaceInFrame = true

            // Far distance checking
            if face.normalizedBoundingBox.width < CGFloat(FaceRecognitionPipeline.minimumProminentFaceWidth) {
                self.enrollmentGuidance = "Bring your face closer to the camera"
                self.matchStreak = 0
                self.poseHoldStartedAt = nil
                self.isHoldingPose = false
                return
            }

            // Pose matching
            guard currentPoseIndex < poses.count else { return }
            let pose = poses[currentPoseIndex]
            let yaw = face.yaw ?? 0
            let pitch = face.pitch ?? 0

            let isMatching = checkPoseMatch(pose: pose, yaw: yaw, pitch: pitch)

            if isMatching {
                matchStreak += 1
                if matchStreak >= requiredMatchStreak {
                    self.isHoldingPose = true
                    if poseHoldStartedAt == nil {
                        poseHoldStartedAt = Date()
                    }

                    if let started = poseHoldStartedAt, Date().timeIntervalSince(started) >= poseHoldDuration {
                        // Capture valid frame sample
                        if let result = try? pipeline.recognize(face, in: frame.image) {
                            let sample = FaceSample(
                                embedding: result.embedding,
                                pose: pose.name,
                                capturedAt: Date(),
                                quality: result.quality ?? 0.85
                            )
                            collectedSamples.append(sample)
                            capturedForCurrentPose += 1

                            // Recalculate progress
                            let totalSamples = Double(poses.count * samplesPerPose)
                            let completed = Double(currentPoseIndex * samplesPerPose + capturedForCurrentPose)
                            self.enrollmentProgress = min(completed / totalSamples, 1.0)

                            // Check if current pose quota fulfilled
                            if capturedForCurrentPose >= samplesPerPose {
                                currentPoseIndex += 1
                                capturedForCurrentPose = 0
                                matchStreak = 0
                                poseHoldStartedAt = nil
                                self.isHoldingPose = false

                                if currentPoseIndex < poses.count {
                                    self.enrollmentGuidance = poses[currentPoseIndex].instruction
                                } else {
                                    finishEnrollment()
                                }
                            }
                        }
                    }
                }
            } else {
                matchStreak = 0
                poseHoldStartedAt = nil
                self.isHoldingPose = false
                self.enrollmentGuidance = pose.instruction
            }
        } catch {
            // Frame processing retry
        }
    }

    private func checkPoseMatch(pose: EnrollmentPose, yaw: Float, pitch: Float) -> Bool {
        let yawThresh: Float = 0.20
        let pitchThresh: Float = 0.15

        switch pose {
        case .center:
            return abs(yaw) < 0.18 && abs(pitch) < 0.14
        case .left:
            return yaw > yawThresh && abs(pitch) < 0.18
        case .right:
            return yaw < -yawThresh && abs(pitch) < 0.18
        case .top:
            return pitch < -pitchThresh && abs(yaw) < 0.20
        case .bottom:
            return pitch > pitchThresh && abs(yaw) < 0.20
        case .topLeft:
            return yaw > (yawThresh * 0.7) && pitch < -(pitchThresh * 0.7)
        case .topRight:
            return yaw < -(yawThresh * 0.7) && pitch < -(pitchThresh * 0.7)
        case .bottomLeft:
            return yaw > (yawThresh * 0.7) && pitch > (pitchThresh * 0.7)
        case .bottomRight:
            return yaw < -(yawThresh * 0.7) && pitch > (pitchThresh * 0.7)
        }
    }

    private func finishEnrollment() {
        self.isEnrollmentComplete = true
        self.enrollmentGuidance = "Face ID Profile Ready!"
        stopInteractiveEnrollment()

        // Extract embeddings
        let embeddings = collectedSamples.map(\.embedding)
        if let avg = FaceEmbedding.average(embeddings) {
            self.enrolledEmbedding = avg
        } else if let first = embeddings.first {
            self.enrolledEmbedding = first
        }

        UserDefaults.standard.set(self.enrolledEmbedding, forKey: self.enrollmentKey)
        self.hasEnrolledFace = true
        self.statusMessage = "Face Profile Enrolled (Glance 9-Pose Engine)"

        // Save into FaceEnrollmentStore so FaceUnlockCoordinator immediately uses it
        let store = FaceEnrollmentStore.shared
        store.reloadIfUnlocked()
        if !store.isLocked {
            _ = try? store.commitEnrollment(
                replacing: nil,
                name: NSFullUserName(),
                samples: collectedSamples,
                embedder: pipeline.embedder
            )
        }

        SoundEffectManager.playActionBeep()
    }

    private func loadEnrolledFace() {
        FaceEnrollmentStore.shared.reloadIfUnlocked()
        if !FaceEnrollmentStore.shared.activeIdentities.isEmpty {
            self.hasEnrolledFace = true
        } else if let stored = UserDefaults.standard.array(forKey: enrollmentKey) as? [Float], !stored.isEmpty {
            self.enrolledEmbedding = stored
            self.hasEnrolledFace = true
        }
    }

    public func clearEnrolledFace() {
        UserDefaults.standard.removeObject(forKey: enrollmentKey)
        self.enrolledEmbedding = []
        self.collectedSamples = []
        self.hasEnrolledFace = false
        self.statusMessage = "Face profile removed"
        FaceEnrollmentStore.shared.deleteAll()
    }

    public func enrollCurrentFace() {
        startInteractiveEnrollment()
    }
}
