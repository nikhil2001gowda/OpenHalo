import SwiftUI

public struct AudioWaveformBarView: View {
    public var isPlaying: Bool
    public var color: Color

    @State private var barHeights: [CGFloat] = [0.3, 0.7, 1.0, 0.5]
    @State private var timer: Timer?

    public init(isPlaying: Bool, color: Color = Color(red: 0.19, green: 0.82, blue: 0.35)) {
        self.isPlaying = isPlaying
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2.5, height: isPlaying ? max(barHeights[index] * 12, 3) : 3)
            }
        }
        .frame(height: 12)
        .onAppear {
            updateAnimationState()
        }
        .onChange(of: isPlaying) {
            updateAnimationState()
        }
    }

    private func updateAnimationState() {
        timer?.invalidate()
        if isPlaying {
            timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.15)) {
                    barHeights = (0..<4).map { _ in CGFloat.random(in: 0.25...1.0) }
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                barHeights = [0.25, 0.25, 0.25, 0.25]
            }
        }
    }
}
