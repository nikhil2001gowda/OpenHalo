import SwiftUI
import AVFoundation
import AppKit

public struct MirrorExpandedView: View {
    @ObservedObject var mirrorService: MirrorService

    public init(mirrorService: MirrorService) {
        self.mirrorService = mirrorService
    }

    public var body: some View {
        VStack(spacing: 10) {
            if !mirrorService.hasPermission {
                // Request Permission UI
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.blue)

                    Text("Quick Camera Mirror")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Check your appearance right from the notch before video calls.")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

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
                    .padding(.top, 4)
                }
                .padding(.vertical, 20)
            } else {
                // Live Camera View
                ZStack {
                    CameraPreviewRepresentable(session: mirrorService.session)
                        .frame(width: 280, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )

                    // Mirror indicator badge
                    VStack {
                        HStack {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Live Mirror")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())

                            Spacer()
                        }
                        .padding(8)
                        Spacer()
                    }
                }
                .frame(width: 280, height: 140)

                // Bottom Camera Selector
                HStack {
                    Text("Looking Good ✨")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))

                    Spacer()

                    if mirrorService.availableCameras.count > 1 {
                        Picker("", selection: $mirrorService.selectedCameraID) {
                            ForEach(mirrorService.availableCameras, id: \.uniqueID) { camera in
                                Text(camera.localizedName).tag(camera.uniqueID as String?)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct CameraPreviewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.videoPreviewLayer.session = session
    }
}

class CameraPreviewNSView: NSView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer.")
        }
        return layer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }

    override func makeBackingLayer() -> CALayer {
        let layer = AVCaptureVideoPreviewLayer()
        return layer
    }
}

