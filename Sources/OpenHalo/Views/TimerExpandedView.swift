import SwiftUI

public struct TimerExpandedView: View {
    @ObservedObject var timerService: TimerService
    @State private var customMinutes: Int = 15

    public init(timerService: TimerService) {
        self.timerService = timerService
    }

    public var body: some View {
        VStack(spacing: 12) {
            if !timerService.isRunning && !timerService.isFinishedAlert {
                // Atoll Tactile Horizontal Ruler Timer Picker
                AtollRulerTimerPicker(
                    selectedMinutes: $customMinutes,
                    tintColor: .orange,
                    onStart: {
                        timerService.start(duration: Double(customMinutes * 60), presetName: "\(customMinutes) min")
                    }
                )

                // Quick Presets Bar
                HStack(spacing: 8) {
                    ForEach(TimerService.defaultPresets) { preset in
                        Button(action: {
                            timerService.start(duration: preset.seconds, presetName: preset.title)
                        }) {
                            Text(preset.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(timerService.activePresetName == preset.title ? Color.orange : Color.white.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // Active Running / Alert Timer Display
                HStack(spacing: 20) {
                    // Circular Ring & Countdown
                    ZStack {
                        CircularProgressRing(
                            progress: timerService.progress,
                            lineWidth: 4,
                            primaryColor: timerService.isFinishedAlert ? .red : .orange
                        )
                        .frame(width: 58, height: 58)

                        Text(timerService.formattedRemainingTime)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    // Status & Controls
                    VStack(alignment: .leading, spacing: 6) {
                        if timerService.isFinishedAlert {
                            Text("Timer Finished!")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)

                            Button(action: { timerService.dismissAlert() }) {
                                Text("Dismiss")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(timerService.activePresetName ?? "Focus Timer")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            HStack(spacing: 10) {
                                Button(action: {
                                    if timerService.isPaused {
                                        timerService.resume()
                                    } else {
                                        timerService.pause()
                                    }
                                }) {
                                    Image(systemName: timerService.isPaused ? "play.fill" : "pause.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Color.white.opacity(0.18))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Button(action: { timerService.stop() }) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                        .frame(width: 26, height: 26)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()
                }

                // Presets Bar
                HStack(spacing: 8) {
                    ForEach(TimerService.defaultPresets) { preset in
                        Button(action: {
                            timerService.start(duration: preset.seconds, presetName: preset.title)
                        }) {
                            Text(preset.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(timerService.activePresetName == preset.title ? Color.orange : Color.white.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

