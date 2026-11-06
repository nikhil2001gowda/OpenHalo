import SwiftUI
import AVFoundation

public struct FaceIDEnrollmentView: View {
    @ObservedObject var faceService: ScreenLockFaceService
    var onDismiss: () -> Void

    @MainActor
    public init(
        faceService: ScreenLockFaceService? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.faceService = faceService ?? ScreenLockFaceService.shared
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "faceid")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(faceService.isEnrollmentComplete ? .green : .cyan)
                    .padding(.top, 8)

                Text(faceService.isEnrollmentComplete ? "Face ID is Ready" : "Glance 9-Pose Face Enrollment")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(faceService.isEnrollmentComplete
                     ? "Your 9-pose face profile is securely registered on-device."
                     : "Position your face in the circle and complete the guided poses to capture multi-angle data.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Central Circular Scanner with 36 Radial Ticks & 9-Pose indicators
            ZStack {
                // Outer 36-Tick Radial Face ID Ring
                faceIDTickRing

                // Live Camera Circle
                ZStack {
                    if let session = faceService.activeSession {
                        GlancePreviewView(session: session)
                            .frame(width: 176, height: 176)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 176, height: 176)
                            .overlay(
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(Color.white.opacity(0.2))
                            )
                    }

                    // Face Detected Corner Guides & Holding Pose Ring
                    if faceService.detectedFaceInFrame && !faceService.isEnrollmentComplete {
                        Circle()
                            .stroke(
                                faceService.isHoldingPose ? Color.green : Color.cyan.opacity(0.6),
                                lineWidth: faceService.isHoldingPose ? 3 : 2
                            )
                            .frame(width: 168, height: 168)
                            .scaleEffect(faceService.isHoldingPose ? 1.03 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: faceService.isHoldingPose)
                    }

                    // Success Checkmark Overlay
                    if faceService.isEnrollmentComplete {
                        Circle()
                            .fill(Color.black.opacity(0.75))
                            .frame(width: 176, height: 176)

                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.green)
                                .transition(.scale.combined(with: .opacity))

                            Text("Complete")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(width: 230, height: 230)
            .padding(.vertical, 4)

            // Dynamic Guidance & Progress
            VStack(spacing: 6) {
                Text(faceService.enrollmentGuidance)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(faceService.isEnrollmentComplete ? .green : (faceService.isHoldingPose ? .green : .white))
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: faceService.enrollmentGuidance)

                if !faceService.isEnrollmentComplete {
                    Text("Pose \(min(faceService.currentPoseIndex + 1, 9)) of 9 • \(Int(faceService.enrollmentProgress * 100))% Scanned")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.55))

                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 4)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .green],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(faceService.enrollmentProgress), height: 4)
                                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: faceService.enrollmentProgress)
                        }
                    }
                    .frame(width: 160, height: 4)
                }
            }

            // Launch Native Notch Sweep Option
            if !faceService.isEnrollmentComplete {
                Button(action: {
                    faceService.stopInteractiveEnrollment()
                    onDismiss()
                    faceService.launchGlanceGuidedNotchSweep()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "macbook.and.iphone")
                            .font(.system(size: 10))
                        Text("Switch to Native Notch Drop Guided Sweep")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.10))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 12) {
                if faceService.isEnrollmentComplete {
                    Button(action: {
                        faceService.stopInteractiveEnrollment()
                        onDismiss()
                    }) {
                        Text("Done")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        faceService.stopInteractiveEnrollment()
                        onDismiss()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 320, height: 460)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .onAppear {
            faceService.startInteractiveEnrollment()
        }
        .onDisappear {
            faceService.stopInteractiveEnrollment()
        }
    }

    // MARK: - 36-Tick Radial Face ID Ring

    private var faceIDTickRing: some View {
        ZStack {
            ForEach(0..<36) { index in
                let angle = Double(index) * 10.0
                let isLit = Double(index) / 36.0 <= faceService.enrollmentProgress

                Rectangle()
                    .fill(isLit ? (faceService.isEnrollmentComplete ? Color.green : Color.cyan) : Color.white.opacity(0.15))
                    .frame(width: isLit ? 2.5 : 1.8, height: isLit ? 10 : 7)
                    .offset(y: -102)
                    .rotationEffect(.degrees(angle))
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isLit)
            }
        }
    }
}
