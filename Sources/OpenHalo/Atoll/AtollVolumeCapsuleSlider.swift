/*
 * Adapted from Atoll (DynamicIsland) by Ebullioscopic
 * iOS-Grade Volume Capsule Slider with Hover Swell & Dynamic Speaker Illumination
 */

import SwiftUI

public struct AtollVolumeCapsuleSlider: View {
    @Binding var value: Double
    let tint: Color
    let compact: Bool
    var onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging = false
    @State private var isHovering = false

    private var trackHeight: CGFloat { compact ? 9 : 12 }
    private var glyphSize: CGFloat { compact ? 10 : 12 }

    private var isEngaged: Bool { isDragging || isHovering }
    private var trackSaturation: Double { isEngaged ? 1 : 0.2 }
    private var fillOpacity: Double { isDragging ? 1.0 : (isHovering ? 0.85 : 0.6) }

    private var quietGlyphOpacity: Double { 0.3 + (1 - fraction) * 0.55 }
    private var loudGlyphOpacity: Double { 0.3 + fraction * 0.55 }

    private var quietGlyphName: String {
        fraction <= 0.001 ? "speaker.slash.fill" : "speaker.fill"
    }

    private var fraction: Double { min(max(value, 0), 1) }

    public init(
        value: Binding<Double>,
        tint: Color = .white,
        compact: Bool = false,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.tint = tint
        self.compact = compact
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        HStack(spacing: compact ? 7 : 9) {
            Image(systemName: quietGlyphName)
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundColor(tint.opacity(quietGlyphOpacity))
                .frame(width: glyphSize + 4, alignment: .leading)

            track

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundColor(tint.opacity(loudGlyphOpacity))
                .frame(width: glyphSize + 4, alignment: .trailing)
        }
        .animation(.easeOut(duration: 0.2), value: fraction)
        .saturation(trackSaturation)
    }

    private var track: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let filled = max(trackHeight, width * CGFloat(fraction))

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(tint.opacity(isEngaged ? 0.22 : 0.12))

                Capsule(style: .continuous)
                    .fill(tint.opacity(fillOpacity))
                    .frame(width: filled)
            }
            .frame(height: trackHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                isDragging = true
                            }
                            onEditingChanged?(true)
                        }
                        update(to: gesture.location.x, width: width)
                    }
                    .onEnded { gesture in
                        update(to: gesture.location.x, width: width)
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            isDragging = false
                        }
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: trackHeight)
        .scaleEffect(x: 1, y: isDragging ? 1.15 : 1, anchor: .center)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isDragging)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
    }

    private func update(to x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        value = min(max(Double(x / width), 0), 1)
    }
}

