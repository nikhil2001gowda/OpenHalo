/*
 * Adapted from Atoll (DynamicIsland) by Ebullioscopic
 * Apple Activity-Ring Style Circular Gauge for Hardware Metrics
 */

import SwiftUI

public struct AtollRingArc: View {
    public let start: Double
    public let end: Double
    public let color: Color
    public var lineWidth: CGFloat = 8

    public init(start: Double, end: Double, color: Color, lineWidth: CGFloat = 8) {
        self.start = start
        self.end = end
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        Circle()
            .trim(from: CGFloat(start), to: CGFloat(end))
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

public struct AtollCircularGaugeView: View {
    public let title: String
    public let value: Double // 0.0 ... 1.0
    public let tint: Color
    public let centerIcon: String
    public let centerPrimaryText: String
    public var subtitle: String? = nil
    public var size: CGFloat = 68
    public var lineWidth: CGFloat = 7

    public init(
        title: String,
        value: Double,
        tint: Color,
        centerIcon: String,
        centerPrimaryText: String,
        subtitle: String? = nil,
        size: CGFloat = 68,
        lineWidth: CGFloat = 7
    ) {
        self.title = title
        self.value = value
        self.tint = tint
        self.centerIcon = centerIcon
        self.centerPrimaryText = centerPrimaryText
        self.subtitle = subtitle
        self.size = size
        self.lineWidth = lineWidth
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(tint.opacity(0.15), lineWidth: lineWidth)
                    .frame(width: size, height: size)

                // Foreground Progress Arc
                if value > 0 {
                    AtollRingArc(start: 0, end: min(max(value, 0.02), 1.0), color: tint, lineWidth: lineWidth)
                        .frame(width: size, height: size)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: value)
                }

                // Center Icon + Metric Value
                VStack(spacing: 2) {
                    Image(systemName: centerIcon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(tint)

                    Text(centerPrimaryText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
}
