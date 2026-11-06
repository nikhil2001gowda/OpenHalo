/*
 * Adapted from Atoll (DynamicIsland) by Ebullioscopic
 * Glowing Pulsating Recording / Mic Activity Indicator
 */

import SwiftUI

public struct AtollRecordingIndicator: View {
    public let isActive: Bool
    public let color: Color
    public let indicatorSize: CGFloat

    @State private var isPulsing: Bool = false

    public init(isActive: Bool, color: Color = .red, indicatorSize: CGFloat = 8) {
        self.isActive = isActive
        self.color = color
        self.indicatorSize = indicatorSize
    }

    public var body: some View {
        Group {
            if isActive {
                ZStack {
                    // Outer diffuse aura
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: indicatorSize * 2.2, height: indicatorSize * 2.2)
                        .blur(radius: 2)
                        .scaleEffect(isPulsing ? 1.25 : 0.95)

                    // Middle ring
                    Circle()
                        .fill(color.opacity(0.5))
                        .frame(width: indicatorSize * 1.5, height: indicatorSize * 1.5)
                        .scaleEffect(isPulsing ? 1.15 : 1.0)

                    // Core bright dot
                    Circle()
                        .fill(color)
                        .frame(width: indicatorSize, height: indicatorSize)
                        .opacity(isPulsing ? 1.0 : 0.75)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isActive)
    }
}
