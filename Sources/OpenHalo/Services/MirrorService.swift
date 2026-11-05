import Foundation
@preconcurrency import AVFoundation
import AppKit

@MainActor
public final class MirrorService: ObservableObject {
    @Published public var session: AVCaptureSession = AVCaptureSession()
    @Published public var isRunning: Bool = false
    @Published public var hasPermission: Bool = false
    @Published public var availableCameras: [AVCaptureDevice] = []
    @Published public var selectedCameraID: String? = nil

    private let sessionQueue = DispatchQueue(label: "com.openhalo.mirror.sessionQueue", qos: .userInitiated)

    public init() {
        checkPermission()
        discoverCameras()
    }

    public func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.hasPermission = true
        case .notDetermined:
            self.hasPermission = false
        default:
            self.hasPermission = false
        }
    }

    public func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor [weak self] in
                self?.hasPermission = granted
                if granted {
                    self?.discoverCameras()
                    self?.startSession()
                }
            }
        }
    }

    public func discoverCameras() {
        let types: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            types = [.builtInWideAngleCamera, .external]
        } else {
            types = [.builtInWideAngleCamera]
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        self.availableCameras = discovery.devices
        if selectedCameraID == nil {
            selectedCameraID = discovery.devices.first?.uniqueID
        }
    }

    public func startSession() {
        checkPermission()
        guard hasPermission else {
            requestPermission()
            return
        }

        setupSession()
        let captureSession = self.session
        guard !captureSession.isRunning else {
            self.isRunning = true
            return
        }

        sessionQueue.async { [weak self] in
            captureSession.startRunning()
            Task { @MainActor [weak self] in
                self?.isRunning = captureSession.isRunning
            }
        }
    }

    public func stopSession() {
        let captureSession = self.session
        guard captureSession.isRunning else {
            self.isRunning = false
            return
        }

        sessionQueue.async { [weak self] in
            captureSession.stopRunning()
            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }
    }

    public func switchCamera(to uniqueID: String) {
        selectedCameraID = uniqueID
        stopSession()
        startSession()
    }

    private func setupSession() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }

        let targetDevice: AVCaptureDevice? = {
            if let id = selectedCameraID {
                return availableCameras.first(where: { $0.uniqueID == id })
            }
            return availableCameras.first
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video)
        }()

        if let device = targetDevice,
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        session.commitConfiguration()
    }
}
