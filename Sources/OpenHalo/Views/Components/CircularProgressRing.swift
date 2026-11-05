import SwiftUI

public struct CircularProgressRing: View {
    public var progress: Double // 0.0 to 1.0
    public var lineWidth: CGFloat
    public var primaryColor: Color
    public var secondaryColor: Color

    public init(
        progress: Double,
        lineWidth: CGFloat = 4,
        primaryColor: Color = .orange,
        secondaryColor: Color = Color.white.opacity(0.15)
    ) {
        self.progress = min(max(progress, 0.0), 1.0)
        self.lineWidth = lineWidth
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(secondaryColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    primaryColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)
        }
    }
}

