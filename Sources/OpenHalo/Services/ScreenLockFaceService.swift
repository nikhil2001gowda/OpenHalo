import Foundation
@preconcurrency import AVFoundation
import Vision
import AppKit
import SwiftUI
import Combine

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
        }
    }
    @Published public var hasEnrolledFace: Bool = false
    @Published public var isAccessibilityGranted: Bool = GlanceKeystrokeInjector.isAccessibilityTrusted()
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
    private var enrolledEmbedding: [Float] = []
    private var collectedEnrollmentEmbeddings: [[Float]] = []

    // Glance Camera & Processing
    private let cameraManager = GlanceCameraManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var watchdogTimer: DispatchWorkItem?
    private var countdownTimer: Timer?
    private var scanStartTime: Date?
    private let maxScanDuration: TimeInterval = 5.0
    private var isProcessingFrame = false

    public override init() {
        super.init()
        self.isFaceAssistEnabled = UserDefaults.standard.bool(forKey: "OpenHalo.FaceID.Enabled")
        loadEnrolledFace()
        registerScreenLockObservers()
        bindCameraFrames()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAccessibilityPermission()
        }
    }

    public func checkAccessibilityPermission() {
        let trusted = GlanceKeystrokeInjector.isAccessibilityTrusted()
        if self.isAccessibilityGranted != trusted {
            self.isAccessibilityGranted = trusted
        }
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        GlanceKeystrokeInjector.promptForAccessibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    public func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    public func requestAccessibilityPermission() {
        openAccessibilitySettings()
    }

    // MARK: - Glance Screen Lock & Wake Observers

    private func registerScreenLockObservers() {
        GlanceLockMonitor.shared.onLockStateChanged = { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .screenLocked:
                self.handleScreenLocked()
            case .wake:
                self.handleScreenWake()
            case .screenUnlocked:
                self.handleScreenUnlocked()
            case .willSleep:
                self.stopAndCleanup()
            }
        }
    }

    public func handleScreenLocked() {
        guard isFaceAssistEnabled else { return }
        self.statusMessage = "Screen Locked: Awaiting Wake"
        self.state = .waitingForLockWake
        start5SecondFaceScan()
    }

    public func handleScreenWake() {
        guard isFaceAssistEnabled else { return }
        guard GlanceLockMonitor.isScreenActuallyLocked() else { return }
        self.statusMessage = "Display Woke: Scanning Face..."
        start5SecondFaceScan()
    }

    public func handleScreenUnlocked() {
        stopAndCleanup()
        self.statusMessage = "Screen Unlocked"
        self.state = .idle
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            IslandCoordinator.shared.state = .compact
        }
    }

    // MARK: - Glance 5-Second Face ID Scan Pipeline

    public func start5SecondFaceScan() {
        guard isFaceAssistEnabled else { return }
        guard !cameraManager.isRunning else { return }

        self.scanStartTime = Date()
        self.state = .scanning(remainingSeconds: 5.0)
        self.statusMessage = "Scanning Face (Glance Engine)..."

        // Show Dynamic Island scanning animation atop lock screen
        IslandCoordinator.shared.showFaceIDScan(isScanning: true, isUnlocked: false)

        // Strict 5.0s watchdog
        watchdogTimer?.cancel()
        let watchdog = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if case .scanning = self.state {
                    self.stopAndCleanup()
                    self.state = .timedOut
                    self.statusMessage = "Scan timed out (5s limit reached). Camera Off."
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        IslandCoordinator.shared.state = .compact
                    }
                }
            }
        }
        self.watchdogTimer = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + maxScanDuration, execute: watchdog)

        // UI countdown ticker
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.scanStartTime else { return }
                let elapsed = Date().timeIntervalSince(start)
                let remaining = max(0.0, self.maxScanDuration - elapsed)
                if remaining > 0 {
                    self.state = .scanning(remainingSeconds: round(remaining * 10) / 10)
                }
            }
        }

        Task {
            _ = await self.cameraManager.start()
            self.activeSession = self.cameraManager.session
        }
    }

    public func stopAndCleanup() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil

        cameraManager.stop()
        activeSession = nil
        isProcessingFrame = false
    }

    // MARK: - Frame Processing via Glance Architecture

    private func bindCameraFrames() {
        cameraManager.$currentFrame
            .compactMap { $0 }
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] frame in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    guard !self.isProcessingFrame else { return }
                    self.isProcessingFrame = true
                    await self.processCameraFrame(frame)
                    self.isProcessingFrame = false
                }
            }
            .store(in: &cancellables)
    }

    private func processCameraFrame(_ frame: GlanceCameraFrame) async {
        do {
            let faces = try GlanceFaceDetector.detectFaces(in: frame.image)
            guard let face = faces.first else {
                if isEnrolling {
                    self.detectedFaceInFrame = false
                }
                return
            }

            guard let crop = GlanceFaceDetector.crop(face, from: frame.image) else { return }

            if isEnrolling {
                self.detectedFaceInFrame = true
                let yaw = Double(face.yaw ?? 0)
                let pitch = Double(face.pitch ?? 0)
                await self.processEnrollmentStep(crop: crop, yaw: yaw, pitch: pitch)
            } else if case .scanning = state {
                await self.evaluateUnlockScan(crop: crop, quality: face.quality ?? 0.5)
            }
        } catch {
            // Continue frame processing
        }
    }

    private func evaluateUnlockScan(crop: CGImage, quality: Float) async {
        guard case .scanning = state else { return }

        // If no enrolled profile, any clear face satisfies test scan
        if enrolledEmbedding.isEmpty {
            recordSuccessfulRecognition(confidence: quality)
            return
        }

        do {
            let liveEmbedding = try GlanceFaceEmbedding.generateEmbedding(for: crop)
            let similarity = GlanceFaceEmbedding.cosineSimilarity(enrolledEmbedding, liveEmbedding)

            // Glance matching threshold: cosine similarity >= 0.65
            if similarity >= 0.65 {
                recordSuccessfulRecognition(confidence: similarity)
            }
        } catch {
            // Keep scanning until timeout
        }
    }

    private func recordSuccessfulRecognition(confidence: Float) {
        // Hard stop camera immediately
        stopAndCleanup()

        self.state = .recognized(confidence: confidence)
        self.lastRecognitionTimestamp = Date()
        self.statusMessage = "Face Recognized (\(Int(confidence * 100))%)! Camera Off."

        SoundEffectManager.playActionBeep()

        // 1. Dynamic Island Face ID Unlock Animation
        IslandCoordinator.shared.showFaceIDScan(isScanning: false, isUnlocked: true)

        // 2. Inject Password via Glance Keystroke Injector
        if let password = KeychainHelper.getPassword(), !password.isEmpty {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.3) {
                KeychainHelper.unlockLockScreen(password: password)
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
            _ = await self.cameraManager.start()
            self.activeSession = self.cameraManager.session
        }
    }

    public func stopInteractiveEnrollment() {
        self.isEnrolling = false
        stopAndCleanup()
    }

    private func processEnrollmentStep(crop: CGImage, yaw: Double, pitch: Double) async {
        guard isEnrolling && !isEnrollmentComplete else { return }

        if let embedding = try? GlanceFaceEmbedding.generateEmbedding(for: crop) {
            collectedEnrollmentEmbeddings.append(embedding)
        }

        let current = enrollmentProgress

        if current < 0.3 {
            self.enrollmentGuidance = "Look directly at the camera"
            if abs(yaw) < 0.25 {
                enrollmentProgress = min(0.3, current + 0.04)
            }
        } else if current < 0.55 {
            self.enrollmentGuidance = "Slowly turn your head to the left"
            if yaw < -0.15 {
                enrollmentProgress = min(0.55, current + 0.04)
            } else {
                enrollmentProgress = min(0.55, current + 0.015)
            }
        } else if current < 0.8 {
            self.enrollmentGuidance = "Slowly turn your head to the right"
            if yaw > 0.15 {
                enrollmentProgress = min(0.8, current + 0.04)
            } else {
                enrollmentProgress = min(0.8, current + 0.015)
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
        stopAndCleanup()

        if !collectedEnrollmentEmbeddings.isEmpty {
            let dim = collectedEnrollmentEmbeddings[0].count
            var averaged: [Float] = Array(repeating: 0.0, count: dim)
            for sample in collectedEnrollmentEmbeddings {
                for i in 0..<min(dim, sample.count) {
                    averaged[i] += sample[i]
                }
            }
            let count = Float(collectedEnrollmentEmbeddings.count)
            let averagedVec = averaged.map { $0 / count }
            self.enrolledEmbedding = GlanceFaceEmbedding.l2Normalized(averagedVec)
        } else {
            self.enrolledEmbedding = []
        }

        UserDefaults.standard.set(self.enrolledEmbedding, forKey: self.enrollmentKey)
        self.hasEnrolledFace = true
        self.statusMessage = "Face Profile Enrolled (Glance Engine)"

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
    }

    public func enrollCurrentFace() {
        startInteractiveEnrollment()
    }
}
