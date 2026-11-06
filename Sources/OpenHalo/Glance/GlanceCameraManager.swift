//
//  GlanceCameraManager.swift
//  Glance Engine for OpenHalo
//
//  Directly from jonnyoo/glance: Owns AVCaptureSession and publishes frames on background queue.
//

@preconcurrency import AVFoundation
import CoreImage
import CoreGraphics
import AppKit

public struct GlanceCameraFrame: Sendable {
    public let id: UInt64
    public let image: CGImage
    public let sourceSize: CGSize
}

@MainActor
public final class GlanceCameraManager: NSObject, ObservableObject {
    public static let shared = GlanceCameraManager()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentFrame: GlanceCameraFrame?
    @Published public private(set) var errorMessage: String?

    public let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.openhalo.glance.camera.session", qos: .userInitiated)
    private var isConfigured = false
    private var currentInput: AVCaptureDeviceInput?
    private var frameCount: UInt64 = 0

    public override init() {
        super.init()
    }

    public func start() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                errorMessage = "Camera access denied by user."
                return false
            }
        default:
            errorMessage = "Camera access denied. Please enable Camera in System Settings."
            return false
        }

        errorMessage = nil
        configureSessionIfNeeded()
        reconcileDeviceIfNeeded()

        sessionQueue.async { [session = self.session] in
            if !session.isRunning {
                session.startRunning()
            }
        }
        self.isRunning = true
        return true
    }

    public func stop() {
        sessionQueue.async { [session = self.session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
        self.isRunning = false
        self.currentFrame = nil
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        session.beginConfiguration()
        session.sessionPreset = .high
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        session.commitConfiguration()
    }

    private func reconcileDeviceIfNeeded() {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
        guard let dev = device else {
            errorMessage = "No camera device found."
            return
        }
        guard dev.uniqueID != currentInput?.device.uniqueID else { return }

        session.beginConfiguration()
        if let currentInput {
            session.removeInput(currentInput)
        }
        if let input = try? AVCaptureDeviceInput(device: dev), session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        } else {
            currentInput = nil
            errorMessage = "Failed to open camera device input."
        }
        session.commitConfiguration()
    }
}

extension GlanceCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else { return }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.frameCount &+= 1
            self.currentFrame = GlanceCameraFrame(
                id: self.frameCount,
                image: cgImage,
                sourceSize: CGSize(width: width, height: height)
            )
        }
    }
}
