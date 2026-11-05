import Foundation
@preconcurrency import AVFoundation
@preconcurrency import Vision
import AppKit

@MainActor
public final class PresenceDetectionService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published public var isAnalyzing: Bool = false
    @Published public var facesDetectedCount: Int = 0
    @Published public var isUserPresent: Bool = false
    @Published public var lastCheckTime: Date? = nil
    @Published public var statusMessage: String = "Ready for presence check"

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var isCapturingSingleFrame = false

    public override init() {
        super.init()
    }

    /// Performs an instantaneous on-device face & presence check.
    /// Captures a single frame, runs Apple Vision face detection, and stops immediately.
    public func performInstantPresenceCheck() {
        guard !isAnalyzing else { return }
        self.isAnalyzing = true
        self.statusMessage = "Analyzing camera presence..."

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSingleFrameAnalysis()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    if granted {
                        self?.startSingleFrameAnalysis()
                    } else {
                        self?.isAnalyzing = false
                        self?.statusMessage = "Camera access denied"
                    }
                }
            }
        default:
            self.isAnalyzing = false
            self.statusMessage = "Camera access required"
        }
    }

    private func startSingleFrameAnalysis() {
        let session = AVCaptureSession()
        session.sessionPreset = .low

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            self.isAnalyzing = false
            self.statusMessage = "No camera found"
            return
        }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        let queue = DispatchQueue(label: "com.openhalo.vision.presenceQueue")
        output.setSampleBufferDelegate(self, queue: queue)

        guard session.canAddOutput(output) else {
            self.isAnalyzing = false
            self.statusMessage = "Output setup failed"
            return
        }

        session.addOutput(output)
        self.captureSession = session
        self.videoOutput = output
        self.isCapturingSingleFrame = true

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()

            // Emergency timeout to guarantee camera LED power cutoff after max 1.5s
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.stopAndCleanup()
                }
            }
        }
    }

    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Process single frame with Vision
        let request = VNDetectFaceRectanglesRequest { [weak self] req, error in
            let faces = req.results as? [VNFaceObservation] ?? []
            let count = faces.count

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.facesDetectedCount = count
                self.isUserPresent = count > 0
                self.lastCheckTime = Date()
                self.statusMessage = count > 0 ? "✓ User Present (\(count) face\(count > 1 ? "s" : "") detected)" : "No face detected in frame"
                self.stopAndCleanup()
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }

    public func stopAndCleanup() {
        guard let session = captureSession, session.isRunning else {
            self.isAnalyzing = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session.stopRunning()
            Task { @MainActor [weak self] in
                self?.captureSession = nil
                self?.videoOutput = nil
                self?.isAnalyzing = false
            }
        }
    }
}

