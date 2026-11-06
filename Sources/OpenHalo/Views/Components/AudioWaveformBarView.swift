import SwiftUI

public struct AudioWaveformBarView: View {
    public var isPlaying: Bool
    public var color: Color

    @State private var barHeights: [CGFloat] = [0.35, 0.75, 1.0, 0.55]
    @State private var timer: Timer?

    public init(isPlaying: Bool, color: Color = Color(red: 0.19, green: 0.82, blue: 0.35)) {
        self.isPlaying = isPlaying
        self.color = color
    }

    public var body: some View {
        if isPlaying {
            HStack(spacing: 2.5) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 2.8, height: max(barHeights[index] * 13, 3.5))
                }
            }
            .frame(height: 14)
            .onAppear {
                updateAnimationState()
            }
            .onChange(of: isPlaying) {
                updateAnimationState()
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        } else {
            EmptyView()
        }
    }

    private func updateAnimationState() {
        timer?.invalidate()
        if isPlaying {
            timer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.14)) {
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

