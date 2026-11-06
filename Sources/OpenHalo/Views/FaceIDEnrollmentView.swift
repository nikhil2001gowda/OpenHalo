import SwiftUI
import AVFoundation

public struct FaceIDEnrollmentView: View {
    @ObservedObject var faceService: ScreenLockFaceService
    var onDismiss: () -> Void

    @MainActor
    public init(
        faceService: ScreenLockFaceService = ScreenLockFaceService.shared,
        onDismiss: @escaping () -> Void
    ) {
        self.faceService = faceService
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "faceid")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(faceService.isEnrollmentComplete ? .green : .cyan)
                    .padding(.top, 8)

                Text(faceService.isEnrollmentComplete ? "Face ID is Ready" : "Face ID Enrollment")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(faceService.isEnrollmentComplete
                     ? "Your face profile is securely registered on-device."
                     : "Position your face within the frame and move your head slowly around the circle.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Central Circular Scanner with 36 Radial Ticks
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

                    // Face Detected Corner Guides (iPhone Style)
                    if faceService.detectedFaceInFrame && !faceService.isEnrollmentComplete {
                        Circle()
                            .stroke(Color.cyan.opacity(0.6), lineWidth: 2)
                            .frame(width: 168, height: 168)
                            .scaleEffect(1.02)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: faceService.detectedFaceInFrame)
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
                    .foregroundColor(faceService.isEnrollmentComplete ? .green : .white)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: faceService.enrollmentGuidance)

                if !faceService.isEnrollmentComplete {
                    Text("\(Int(faceService.enrollmentProgress * 100))% Scanned")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.5))

                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 4)

                            Capsule()
                                .fill(Color.cyan)
                                .frame(width: geo.size.width * CGFloat(faceService.enrollmentProgress), height: 4)
                                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: faceService.enrollmentProgress)
                        }
                    }
                    .frame(width: 160, height: 4)
                }
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
            .padding(.bottom, 12)
        }
        .frame(width: 320, height: 440)
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
        .onAppear {
            faceService.startInteractiveEnrollment()
        }
        .onDisappear {
            faceService.stopInteractiveEnrollment()
        }
    }

    // MARK: - Radial Face ID 36-Tick Ring

    private var faceIDTickRing: some View {
        ZStack {
            ForEach(0..<36, id: \.self) { index in
                let tickRatio = Double(index) / 36.0
                let isScanned = faceService.isEnrollmentComplete || (tickRatio <= faceService.enrollmentProgress)

                Rectangle()
                    .fill(isScanned ? Color(red: 0.2, green: 0.85, blue: 0.35) : Color.white.opacity(0.15))
                    .frame(width: 3, height: 12)
                    .cornerRadius(1.5)
                    .offset(y: -102)
                    .rotationEffect(.degrees(Double(index) * 10))
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isScanned)
            }
        }
    }
}
