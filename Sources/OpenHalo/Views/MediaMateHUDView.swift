import SwiftUI

public struct MediaMateHUDView: View {
    public let payload: HUDPayload

    public init(payload: HUDPayload) {
        self.payload = payload
    }

    public var body: some View {
        HStack(spacing: 10) {
            // HUD Icon
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 18)

            // iOS-Style Rounded Capsule Progress Slider
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 6)

                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(payload.value))), height: 6)
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: payload.value)
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 12)

            // Percentage Display
            Text("\(Int(payload.value * 100))%")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.85))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
    }

    private var iconName: String {
        switch payload.type {
        case .volume:
            if payload.isMuted || payload.value == 0 {
                return "speaker.slash.fill"
            } else if payload.value < 0.33 {
                return "speaker.wave.1.fill"
            } else if payload.value < 0.66 {
                return "speaker.wave.2.fill"
            } else {
                return "speaker.wave.3.fill"
            }
        case .brightness:
            return payload.value < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .keyboardBacklight:
            return "keyboard.fill"
        }
    }

    private var iconColor: Color {
        switch payload.type {
        case .volume: return payload.isMuted ? .red : .white
        case .brightness: return .yellow
        case .keyboardBacklight: return .cyan
        }
    }

    private var progressColor: Color {
        switch payload.type {
        case .volume: return payload.isMuted ? Color.gray : Color.white
        case .brightness: return Color.yellow
        case .keyboardBacklight: return Color.cyan
        }
    }
}
