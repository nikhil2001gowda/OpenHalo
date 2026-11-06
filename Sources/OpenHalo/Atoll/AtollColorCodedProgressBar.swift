/*
 * Adapted from Atoll (DynamicIsland) by Ebullioscopic
 * Color-Coded Progress Bar with Apple System Palette
 */

import SwiftUI

public enum AtollProgressMode {
    case battery // Green when full, amber at mid, red when low
    case intensity // Red at max, green at low (e.g. CPU, volume)
    case accent(Color)
}

public struct AtollColorCodedProgressBar: View {
    public let value: Double // 0.0 to 1.0
    public let mode: AtollProgressMode
    public let width: CGFloat?
    public let height: CGFloat

    public init(
        value: Double,
        mode: AtollProgressMode = .battery,
        width: CGFloat? = nil,
        height: CGFloat = 4
    ) {
        self.value = min(max(value, 0), 1)
        self.mode = mode
        self.width = width
        self.height = height
    }

    private var fillColor: Color {
        switch mode {
        case .battery:
            if value > 0.45 { return .green }
            if value > 0.20 { return .yellow }
            return .red
        case .intensity:
            if value > 0.80 { return .red }
            if value > 0.50 { return .orange }
            return .cyan
        case .accent(let col):
            return col
        }
    }

    public var body: some View {
        GeometryReader { geo in
            let totalWidth = width ?? geo.size.width
            let fillWidth = max(height, totalWidth * CGFloat(value))

            ZStack(alignment: .leading) {
                // Background track
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: totalWidth, height: height)

                // Fill
                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(width: fillWidth, height: height)
                    .shadow(color: fillColor.opacity(0.4), radius: 2)
            }
        }
        .frame(height: height)
        .frame(width: width)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: value)
    }
}
