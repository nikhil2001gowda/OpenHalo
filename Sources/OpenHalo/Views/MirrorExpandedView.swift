import SwiftUI
import AVFoundation
import AppKit

public struct MirrorExpandedView: View {
    @ObservedObject var mirrorService: MirrorService
    @ObservedObject var presenceService: PresenceDetectionService

    @MainActor
    public init(
        mirrorService: MirrorService,
        presenceService: PresenceDetectionService? = nil
    ) {
        self.mirrorService = mirrorService
        self.presenceService = presenceService ?? IslandCoordinator.shared.presenceService
    }

    public var body: some View {
        VStack(spacing: 8) {
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
                .padding(.vertical, 16)
            } else {
                // Live Camera View
                ZStack {
                    CameraPreviewRepresentable(session: mirrorService.session)
                        .frame(width: 280, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )

                    // Mirror indicator badge & macOS Video Effects Controls
                    VStack {
                        HStack(spacing: 6) {
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

                            // macOS System Video Effects Menu Bar Popover Trigger
                            Button(action: {
                                mirrorService.openSystemVideoEffects()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "sparkles.tv")
                                        .font(.system(size: 9))
                                    Text("Video Effects")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointingHandCursor()
                            .help("Configure macOS Center Stage, Studio Light, Portrait & Reactions")

                            // Direct Center Stage Toggle
                            Button(action: {
                                mirrorService.toggleCenterStage()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .font(.system(size: 9))
                                    Text(mirrorService.isCenterStageActive ? "Center Stage On" : "Center Stage")
                                        .font(.system(size: 9, weight: mirrorService.isCenterStageActive ? .bold : .regular))
                                }
                                .foregroundColor(mirrorService.isCenterStageActive ? .blue : Color.white.opacity(0.8))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(mirrorService.isCenterStageActive ? Color.blue.opacity(0.3) : Color.black.opacity(0.65))
                                .clipShape(Capsule())
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointingHandCursor()
                            .help("Toggle macOS Center Stage auto-framing")

                            // On-Device Vision Presence Trigger
                            Button(action: {
                                presenceService.performInstantPresenceCheck()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: presenceService.isAnalyzing ? "sparkles" : "person.fill.viewfinder")
                                        .font(.system(size: 9.5))
                                    Text(presenceService.isAnalyzing ? "Scanning..." : "Vision Check")
                                        .font(.system(size: 9.5, weight: .medium))
                                }
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.65))
                                .clipShape(Capsule())
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointingHandCursor()
                        }
                        .padding(6)

                        Spacer()

                        // Active Video Effects Indicators & Vision Result Toast
                        HStack(spacing: 6) {
                            if mirrorService.isStudioLightActive {
                                HStack(spacing: 3) {
                                    Image(systemName: "light.beacon.max.fill")
                                        .font(.system(size: 8))
                                    Text("Studio Light")
                                        .font(.system(size: 8.5, weight: .medium))
                                }
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.75))
                                .cornerRadius(5)
                            }

                            if mirrorService.isPortraitActive {
                                HStack(spacing: 3) {
                                    Image(systemName: "f.cursive")
                                        .font(.system(size: 8))
                                    Text("Portrait")
                                        .font(.system(size: 8.5, weight: .medium))
                                }
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.75))
                                .cornerRadius(5)
                            }

                            if presenceService.isUserPresent || presenceService.facesDetectedCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.green)
                                    Text(presenceService.statusMessage)
                                        .font(.system(size: 8.5, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.75))
                                .cornerRadius(5)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
                .frame(width: 320, height: 140)

                // Bottom Camera Selector
                HStack {
                    Text("Looking Good ✨ (Mirror Locked Open)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))

                    Spacer()

                    if mirrorService.availableCameras.count > 1 {
                        Picker("", selection: $mirrorService.selectedCameraID) {
                            ForEach(mirrorService.availableCameras, id: \.uniqueID) { camera in
                                Text(camera.localizedName).tag(camera.uniqueID as String?)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
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
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        nsView.videoPreviewLayer.frame = nsView.bounds
        CATransaction.commit()
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
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoPreviewLayer.frame = bounds
        CATransaction.commit()
    }
}
