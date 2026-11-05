import SwiftUI
@preconcurrency import AVFoundation
import AppKit

public struct MirrorExpandedView: View {
    @ObservedObject var mirrorService: MirrorService

    public init(mirrorService: MirrorService, presenceService: PresenceDetectionService? = nil) {
        self.mirrorService = mirrorService
    }

    public var body: some View {
        VStack(spacing: 8) {
            if !mirrorService.hasPermission {
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.blue)

                    Text("Camera Mirror")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Quick appearance check before calls.")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.6))

                    Button(action: {
                        mirrorService.requestPermission()
                    }) {
                        Text("Enable Camera")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.vertical, 16)
            } else {
                // Live Viewfinder
                ZStack(alignment: .topLeading) {
                    SimpleCameraPreviewView(session: mirrorService.session)
                        .frame(width: 320, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                        )

                    // Live Badge
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Live Mirror")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .padding(8)
                }
                .frame(width: 320, height: 140)

                // Bottom Footer
                HStack {
                    Text("Looking Good ✨")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))

                    Spacer()

                    if mirrorService.availableCameras.count > 1 {
                        Picker("", selection: Binding(
                            get: { mirrorService.selectedCameraID },
                            set: { if let id = $0 { mirrorService.switchCamera(to: id) } }
                        )) {
                            ForEach(mirrorService.availableCameras, id: \.uniqueID) { camera in
                                Text(camera.localizedName).tag(camera.uniqueID as String?)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        .pointingHandCursor()
                    }
                }
                .padding(.horizontal, 14)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            mirrorService.startSession()
        }
        .onDisappear {
            mirrorService.stopSession()
        }
    }
}

// MARK: - Reliable Direct Preview Representable

public typealias CameraPreviewRepresentable = SimpleCameraPreviewView

public struct SimpleCameraPreviewView: NSViewRepresentable {
    public let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public func makeNSView(context: Context) -> SimpleCameraPreviewNSView {
        return SimpleCameraPreviewNSView(session: session)
    }

    public func updateNSView(_ nsView: SimpleCameraPreviewNSView, context: Context) {
        nsView.setSession(session)
    }
}

public final class SimpleCameraPreviewNSView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

    public init(session: AVCaptureSession) {
        super.init(frame: .zero)
        self.wantsLayer = true
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }

    public func setSession(_ session: AVCaptureSession) {
        if previewLayer.session != session {
            previewLayer.session = session
        }
    }
}
