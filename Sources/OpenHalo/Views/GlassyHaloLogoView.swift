import SwiftUI

public struct GlassyHaloLogoView: View {
    public let size: CGFloat

    public init(size: CGFloat = 36) {
        self.size = size
    }

    private var orbRadius: CGFloat {
        size * 0.165
    }

    private var centerDistance: CGFloat {
        orbRadius * 1.95
    }

    public var body: some View {
        ZStack {
            // Ambient halo glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.48
                    )
                )

            // Surrounding 6 glass nodes
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) * (.pi / 3.0)
                let x = CGFloat(cos(angle)) * centerDistance
                let y = CGFloat(sin(angle)) * centerDistance

                singleGlassOrb
                    .offset(x: x, y: y)
            }

            // Center glass nucleus
            singleGlassOrb
        }
        .frame(width: size, height: size)
    }

    private var singleGlassOrb: some View {
        ZStack {
            // Drop shadow / caustics
            Circle()
                .fill(Color.cyan.opacity(0.35))
                .blur(radius: orbRadius * 0.3)
                .offset(y: orbRadius * 0.15)

            // 3D Glass Sphere Body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.75, green: 0.95, blue: 1.0),
                            Color(red: 0.05, green: 0.80, blue: 1.0),
                            Color(red: 0.00, green: 0.50, blue: 0.95),
                            Color(red: 0.00, green: 0.25, blue: 0.70)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: orbRadius * 1.2
                    )
                )

            // Violet prism dispersion at bottom-right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.45), Color.clear],
                        center: UnitPoint(x: 0.75, y: 0.75),
                        startRadius: 0,
                        endRadius: orbRadius * 0.9
                    )
                )

            // Specular Glint Crescent
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: orbRadius * 1.0, height: orbRadius * 0.6)
                .offset(x: -orbRadius * 0.2, y: -orbRadius * 0.25)

            // Micro white glint dot
            Circle()
                .fill(Color.white)
                .frame(width: orbRadius * 0.25, height: orbRadius * 0.25)
                .offset(x: -orbRadius * 0.35, y: -orbRadius * 0.35)

            // Fresnel rim stroke
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.8),
                            Color.cyan.opacity(0.4),
                            Color.blue.opacity(0.1),
                            Color.purple.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.8, orbRadius * 0.09)
                )
        }
        .frame(width: orbRadius * 2, height: orbRadius * 2)
    }
}

