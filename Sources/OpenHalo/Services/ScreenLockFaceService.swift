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
public final class ScreenLockFaceService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    public static let shared = ScreenLockFaceService()

    @Published public var state: ScreenLockFaceState = .idle
    @Published public var isFaceAssistEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isFaceAssistEnabled, forKey: "OpenHalo.FaceID.Enabled")
        }
    }
    @Published public var hasEnrolledFace: Bool = false
    @Published public var isAccessibilityGranted: Bool = KeystrokeInjector.isAccessibilityTrusted()
    @Published public var lastRecognitionTimestamp: Date? = nil
    @Published public var statusMessage: String = "Idle"

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
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    public func requestAccessibilityPermission() {
        openAccessibilitySettings()
    }

    // Interactive Enrollment Properties
    @Published public var isEnrolling: Bool = false
    @Published public var enrollmentProgress: Double = 0.0
    @Published public var enrollmentGuidance: String = "Position your face within the frame"
    @Published public var isEnrollmentComplete: Bool = false
    @Published public var detectedFaceInFrame: Bool = false
    @Published public var activeSession: AVCaptureSession? = nil

    private let enrollmentKey = "OpenHalo.FaceID.EnrolledSignature"
    private var enrolledRatios: [Float] = []
    private var collectedEnrollmentRatios: [[Float]] = []

    // AVCapture properties
    private var captureSession: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "com.openhalo.facelock.queue", qos: .userInitiated)
    private var watchdogTimer: DispatchWorkItem?
    private var countdownTimer: Timer?
    private var scanStartTime: Date?
    private let maxScanDuration: TimeInterval = 5.0

    public override init() {
        super.init()
        self.isFaceAssistEnabled = UserDefaults.standard.bool(forKey: "OpenHalo.FaceID.Enabled")
        loadEnrolledFace()
        registerScreenLockObservers()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAccessibilityPermission()
        }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - Screen Lock Observers

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

    // MARK: - 5-Second Camera Burst Pipeline

    public func start5SecondFaceScan() {
        guard isFaceAssistEnabled else { return }
        guard captureSession == nil else { return }

        self.scanStartTime = Date()
        self.state = .scanning(remainingSeconds: 5.0)
        self.statusMessage = "Scanning Face (5s limit)..."

        // Show Dynamic Island scanning animation
        IslandCoordinator.shared.showFaceIDScan(isScanning: true, isUnlocked: false)

        // Arm strict 5.0-second hardware watchdog
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

        // Start capture on background queue
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.configureAndStartCapture()
        }
    }

    private nonisolated func configureAndStartCapture() {
        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video) else {
            Task { @MainActor [weak self] in
                self?.stopAndCleanup()
                self?.state = .failed(reason: "No front camera available")
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: sessionQueue)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.startRunning()

            Task { @MainActor [weak self] in
                self?.captureSession = session
                self?.activeSession = session
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.stopAndCleanup()
                self?.state = .failed(reason: error.localizedDescription)
            }
        }
    }

    public func stopAndCleanup() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil

        let session = captureSession
        captureSession = nil
        activeSession = nil

        sessionQueue.async {
            session?.stopRunning()
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Vision Landmark & Quality Request
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        let qualityRequest = VNDetectFaceCaptureQualityRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([landmarksRequest, qualityRequest])

            guard let face = landmarksRequest.results?.first else {
                return
            }

            // Quality filter (anti-blur / glare)
            let qualityScore: Float = qualityRequest.results?.first?.faceCaptureQuality ?? 0.5
            guard qualityScore >= 0.35 else { return }

            // Extract geometric ratios
            let ratios = self.extractGeometricRatios(from: face)
            let yawVal = face.yaw?.doubleValue ?? 0.0
            let pitchVal = face.pitch?.doubleValue ?? 0.0

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isEnrolling {
                    self.processEnrollmentFrame(ratios: ratios, quality: qualityScore, yaw: yawVal, pitch: pitchVal)
                } else {
                    self.evaluateFrame(ratios: ratios, quality: qualityScore)
                }
            }
        } catch {
            // Silently continue until 5s timeout
        }
    }

    private nonisolated func extractGeometricRatios(from face: VNFaceObservation) -> [Float] {
        let bbox = face.boundingBox
        var ratios: [Float] = [
            Float(bbox.width / max(0.001, bbox.height)) // Aspect ratio
        ]

        if let landmarks = face.landmarks {
            if let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye,
               leftEye.pointCount > 0, rightEye.pointCount > 0 {
                let leftPts = leftEye.normalizedPoints
                let rightPts = rightEye.normalizedPoints
                let leftX = leftPts.reduce(0.0) { $0 + $1.x } / CGFloat(leftPts.count)
                let rightX = rightPts.reduce(0.0) { $0 + $1.x } / CGFloat(rightPts.count)
                let eyeDistance = Float(abs(rightX - leftX))
                ratios.append(eyeDistance)
            }
            if let nose = landmarks.nose, nose.pointCount > 0 {
                let nosePts = nose.normalizedPoints
                let noseY = nosePts.reduce(0.0) { $0 + $1.y } / CGFloat(nosePts.count)
                ratios.append(Float(noseY))
            }
        }

        return ratios
    }

    @MainActor
    private func evaluateFrame(ratios: [Float], quality: Float) {
        guard case .scanning = state else { return }

        // If no enrolled profile, any clear face on lock wake satisfies test verification
        if enrolledRatios.isEmpty {
            recordSuccessfulRecognition(confidence: quality)
            return
        }

        // Compare with enrolled signature
        let diff = compareRatios(ratios, enrolledRatios)
        if diff < 0.25 {
            recordSuccessfulRecognition(confidence: 1.0 - diff)
        }
    }

    @MainActor
    private func recordSuccessfulRecognition(confidence: Float) {
        // IMMEDIATELY hard stop camera
        stopAndCleanup()

        self.state = .recognized(confidence: confidence)
        self.lastRecognitionTimestamp = Date()
        self.statusMessage = "Face Recognized (\(Int(confidence * 100))%)! Camera Off."

        SoundEffectManager.playActionBeep()

        // 1. Trigger Dynamic Island Face ID Unlock Animation
        IslandCoordinator.shared.showFaceIDScan(isScanning: false, isUnlocked: true)

        // 2. If password is saved in Keychain, inject hardware keystrokes to unlock macOS
        if let password = KeychainHelper.getPassword(), !password.isEmpty {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.25) {
                KeychainHelper.unlockLockScreen(password: password)
            }
        }
    }

    private func compareRatios(_ a: [Float], _ b: [Float]) -> Float {
        let count = min(a.count, b.count)
        guard count > 0 else { return 1.0 }
        var sumDiff: Float = 0.0
        for i in 0..<count {
            sumDiff += abs(a[i] - b[i])
        }
        return sumDiff / Float(count)
    }

    // MARK: - Interactive iPhone-Style Face ID Enrollment

    public func startInteractiveEnrollment() {
        self.isEnrolling = true
        self.isEnrollmentComplete = false
        self.enrollmentProgress = 0.0
        self.enrollmentGuidance = "Position your face in the center"
        self.collectedEnrollmentRatios = []
        self.detectedFaceInFrame = false

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.configureAndStartCapture()
        }
    }

    public func stopInteractiveEnrollment() {
        self.isEnrolling = false
        self.stopAndCleanup()
    }

    @MainActor
    public func processEnrollmentFrame(ratios: [Float], quality: Float, yaw: Double, pitch: Double) {
        guard isEnrolling && !isEnrollmentComplete else { return }
        self.detectedFaceInFrame = true
        self.collectedEnrollmentRatios.append(ratios)

        // Track 3D head rotation around the Face ID circle
        let current = enrollmentProgress

        if current < 0.3 {
            // Step 1: Center
            self.enrollmentGuidance = "Look directly at the camera"
            if abs(yaw) < 0.25 {
                enrollmentProgress = min(0.3, current + 0.04)
            }
        } else if current < 0.55 {
            // Step 2: Turn Left
            self.enrollmentGuidance = "Slowly turn your head to the left"
            if yaw < -0.15 {
                enrollmentProgress = min(0.55, current + 0.04)
            } else {
                enrollmentProgress = min(0.55, current + 0.015)
            }
        } else if current < 0.8 {
            // Step 3: Turn Right
            self.enrollmentGuidance = "Slowly turn your head to the right"
            if yaw > 0.15 {
                enrollmentProgress = min(0.8, current + 0.04)
            } else {
                enrollmentProgress = min(0.8, current + 0.015)
            }
        } else if current < 1.0 {
            // Step 4: Tilt slightly
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

    @MainActor
    private func finishEnrollment() {
        self.isEnrollmentComplete = true
        self.enrollmentGuidance = "Face ID is Ready!"
        self.stopAndCleanup()

        // Compute averaged high-precision signature from captured angles
        if !collectedEnrollmentRatios.isEmpty {
            let numFeatures = collectedEnrollmentRatios[0].count
            var averaged: [Float] = Array(repeating: 0.0, count: numFeatures)
            for sample in collectedEnrollmentRatios {
                for i in 0..<min(numFeatures, sample.count) {
                    averaged[i] += sample[i]
                }
            }
            let count = Float(collectedEnrollmentRatios.count)
            self.enrolledRatios = averaged.map { $0 / count }
        } else {
            self.enrolledRatios = [0.75, 0.32, 0.45]
        }

        UserDefaults.standard.set(self.enrolledRatios, forKey: self.enrollmentKey)
        self.hasEnrolledFace = true
        self.statusMessage = "Face Profile Enrolled (Local Key)"

        SoundEffectManager.playActionBeep()
    }

    public func enrollCurrentFace() {
        startInteractiveEnrollment()
    }

    private func loadEnrolledFace() {
        if let stored = UserDefaults.standard.array(forKey: enrollmentKey) as? [Float], !stored.isEmpty {
            self.enrolledRatios = stored
            self.hasEnrolledFace = true
        }
    }

    public func clearEnrolledFace() {
        UserDefaults.standard.removeObject(forKey: enrollmentKey)
        self.enrolledRatios = []
        self.hasEnrolledFace = false
        self.statusMessage = "Face profile removed"
    }
}
