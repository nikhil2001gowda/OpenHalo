/*
 * Adapted from Atoll (DynamicIsland) by Ebullioscopic
 * Tactile Horizontal Ruler Timer Picker with Trackpad Scrubbing & Haptics
 */

import SwiftUI
import AppKit

public struct AtollRulerTimerPicker: View {
    @Binding var selectedMinutes: Int
    let tintColor: Color
    let onStart: () -> Void

    @State private var continuousMinutes: Double = 15.0
    @State private var isDragging: Bool = false
    @State private var dragStartValue: Double = 15.0

    private let range: ClosedRange<Double> = 1...90
    private let tickSpacing: CGFloat = 8.0 // px per minute

    public init(
        selectedMinutes: Binding<Int>,
        tintColor: Color = .cyan,
        onStart: @escaping () -> Void
    ) {
        self._selectedMinutes = selectedMinutes
        self.tintColor = tintColor
        self.onStart = onStart
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Minutes Display
            HStack(spacing: 4) {
                Text("\(Int(continuousMinutes.rounded()))")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(tintColor)

                Text("min")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.top, 6)

                Spacer()

                Button(action: onStart) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Start")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(tintColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)

            // Horizontal Ruler Track
            GeometryReader { geo in
                let midX = geo.size.width / 2.0

                ZStack(alignment: .center) {
                    // Ticks Container
                    Canvas { context, size in
                        let centerOffset = midX - CGFloat(continuousMinutes) * tickSpacing

                        for minute in 1...90 {
                            let x = centerOffset + CGFloat(minute) * tickSpacing
                            if x < -10 || x > size.width + 10 { continue }

                            let isTen = minute % 10 == 0
                            let isFive = minute % 5 == 0

                            let height: CGFloat = isTen ? 18 : (isFive ? 12 : 7)
                            let opacity = isTen ? 0.85 : (isFive ? 0.5 : 0.25)
                            let yTop = (size.height - height) / 2.0

                            let tickRect = CGRect(x: x - 0.75, y: yTop, width: 1.5, height: height)
                            context.fill(Path(roundedRect: tickRect, cornerRadius: 0.75), with: .color(.white.opacity(opacity)))
                        }
                    }

                    // Center Indicator Needle
                    Rectangle()
                        .fill(tintColor)
                        .frame(width: 2, height: 22)
                        .cornerRadius(1)
                        .shadow(color: tintColor.opacity(0.6), radius: 3)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartValue = continuousMinutes
                            }
                            let delta = -Double(value.translation.width / tickSpacing)
                            let newMinutes = min(max(dragStartValue + delta, range.lowerBound), range.upperBound)
                            continuousMinutes = newMinutes
                            selectedMinutes = Int(newMinutes.rounded())
                        }
                        .onEnded { _ in
                            isDragging = false
                            selectedMinutes = Int(continuousMinutes.rounded())
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        }
                )
            }
            .frame(height: 32)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
        }
        .padding(8)
        .onAppear {
            continuousMinutes = Double(selectedMinutes)
        }
    }
}
