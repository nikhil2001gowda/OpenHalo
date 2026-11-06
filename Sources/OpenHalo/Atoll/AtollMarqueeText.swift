/*
 * Adapted from Atoll (DynamicIsland) by Ebullioscopic
 * Continuous Smooth Marquee Scrolling Text for Dynamic Island
 */

import SwiftUI
import AppKit

private struct AtollSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct AtollMeasureSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(GeometryReader { geometry in
            Color.clear.preference(key: AtollSizePreferenceKey.self, value: geometry.size)
        })
    }
}

public struct AtollMarqueeText: View {
    let text: String
    let font: Font
    let textColor: Color
    let frameWidth: CGFloat
    let minDuration: Double

    static let loopSpacing: CGFloat = 24

    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var isAnimating: Bool = false

    public init(
        _ text: String,
        font: Font = .system(size: 11, weight: .medium),
        textColor: Color = .white,
        frameWidth: CGFloat = 160,
        minDuration: Double = 2.5
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.frameWidth = frameWidth
        self.minDuration = minDuration
    }

    private var needsScrolling: Bool {
        textWidth > frameWidth
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: Self.loopSpacing) {
                Text(text)
                if needsScrolling {
                    Text(text)
                }
            }
            .id(text)
            .font(font)
            .foregroundColor(textColor)
            .fixedSize(horizontal: true, vertical: false)
            .offset(x: offset)
            .modifier(AtollMeasureSizeModifier())
            .onPreferenceChange(AtollSizePreferenceKey.self) { size in
                let measured = max(0, (size.width - (needsScrolling ? Self.loopSpacing : 0)) / (needsScrolling ? 2 : 1))
                if measured > 0 && abs(measured - self.textWidth) > 1 {
                    self.textWidth = measured
                    resetAndStart()
                }
            }
            .onChange(of: text) { _, _ in
                resetAndStart()
            }
            .onAppear {
                resetAndStart()
            }
            .onDisappear {
                isAnimating = false
            }
        }
        .frame(width: frameWidth, alignment: .leading)
        .clipped()
    }

    private func resetAndStart() {
        isAnimating = false
        offset = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if needsScrolling {
                isAnimating = true
                startAnimationLoop()
            }
        }
    }

    private func startAnimationLoop() {
        guard isAnimating && needsScrolling else { return }
        let duration = max(2.5, Double(textWidth / 32))

        DispatchQueue.main.asyncAfter(deadline: .now() + minDuration) {
            guard isAnimating else { return }
            withAnimation(.linear(duration: duration)) {
                offset = -(textWidth + Self.loopSpacing)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                guard isAnimating else { return }
                offset = 0
                startAnimationLoop()
            }
        }
    }
}

