import SwiftUI

public struct FaceIDNotchView: View {
    public let isScanning: Bool
    public let isUnlocked: Bool

    @State private var scanRotation: Double = 0

    public init(isScanning: Bool, isUnlocked: Bool) {
        self.isScanning = isScanning
        self.isUnlocked = isUnlocked
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Left Status Icon
            ZStack {
                if isUnlocked {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "faceid")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.cyan)
                        .scaleEffect(isScanning ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isScanning)
                }
            }
            .frame(width: 24, height: 24)

            // Center Status Info
            VStack(alignment: .leading, spacing: 1) {
                Text(isUnlocked ? "Face ID Unlocked" : (isScanning ? "Face ID" : "Face ID Ready"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isUnlocked ? .green : .white)

                Text(isUnlocked ? "Welcome back" : (isScanning ? "Verifying face..." : "Ready"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Right Status Indicator
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                    .transition(.scale)
            } else if isScanning {
                Circle()
                    .trim(from: 0.1, to: 0.85)
                    .stroke(
                        AngularGradient(
                            colors: [.clear, .cyan, .blue],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(scanRotation))
                    .onAppear {
                        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                            scanRotation = 360
                        }
                    }
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 32)
    }
}
