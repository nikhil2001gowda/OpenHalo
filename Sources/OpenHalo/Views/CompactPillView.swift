import SwiftUI

public struct CompactPillView: View {
    @ObservedObject var coordinator = IslandCoordinator.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 12) {
            // Leading Element (Slot-Configurable)
            leadingContent

            Spacer()

            // Trailing Element (Slot-Configurable)
            trailingContent
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
    }

    @ViewBuilder
    private var leadingContent: some View {
        switch coordinator.leadingSlot {
        case .auto:
            smartLeadingContent
        case .nowPlaying:
            nowPlayingLeading
        case .nextEvent:
            nextEventLeading
        case .focusTask:
            focusLeading
        case .weather:
            weatherLeading
        case .timer:
            timerLeading
        case .clock:
            clockLeading
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        HStack(spacing: 7) {
            // Always preserve microphone privacy dot if active for security
            if coordinator.enableMicIndicator && coordinator.audioMonitor.isMicrophoneActive {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 7, height: 7)
                    .shadow(color: .orange.opacity(0.8), radius: 3)
            }

            switch coordinator.trailingSlot {
            case .auto:
                smartTrailingContent
            case .audioWaveform:
                AudioWaveformBarView(isPlaying: coordinator.mediaService.currentTrack.isPlaying, color: .green)
            case .battery:
                batteryTrailing
            case .weather:
                weatherTrailing
            case .micIndicator:
                EmptyView()
            case .volume:
                volumeTrailing
            case .focusTask:
                focusTrailing
            case .none:
                EmptyView()
            }
        }
    }

    // MARK: - Leading Subviews

    @ViewBuilder
    private var smartLeadingContent: some View {
        if coordinator.timerService.isRunning {
            timerLeading
        } else if coordinator.mediaService.currentTrack.isPlaying {
            nowPlayingLeading
        } else if let next = coordinator.calendarService.nextEvent, next.isOngoing {
            nextEventLeading
        } else if !coordinator.fileShelfService.items.isEmpty {
            shelfLeading
        } else {
            if ScreenNotchDetector.detect().hasNotch {
                EmptyView()
            } else {
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var nowPlayingLeading: some View {
        mediaLeadingIcon
            .help(coordinator.mediaService.currentTrack.title.isEmpty ? "Now Playing" : "\(coordinator.mediaService.currentTrack.title) • \(coordinator.mediaService.currentTrack.artist)")
    }

    @ViewBuilder
    private var mediaLeadingIcon: some View {
        let track = coordinator.mediaService.currentTrack
        if let data = track.artworkData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        } else {
            switch track.source {
            case .youtube:
                ZStack {
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .fill(Color(red: 0.95, green: 0.1, blue: 0.1))
                        .frame(width: 18, height: 18)
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                        .offset(x: 0.5)
                }
                .shadow(color: Color.red.opacity(0.4), radius: 2.5, y: 1)

            case .spotify:
                ZStack {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.84, blue: 0.38))
                        .frame(width: 18, height: 18)
                    Image(systemName: "music.note")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.black)
                }
                .shadow(color: Color.green.opacity(0.4), radius: 2.5, y: 1)

            case .appleMusic:
                ZStack {
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.98, green: 0.22, blue: 0.38), Color(red: 0.85, green: 0.1, blue: 0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 18, height: 18)
                    Image(systemName: "music.note")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: Color.pink.opacity(0.4), radius: 2.5, y: 1)

            case .chrome:
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                    Image(systemName: "globe")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.5, blue: 0.95))
                }
                .shadow(color: Color.blue.opacity(0.3), radius: 2, y: 1)

            case .safari:
                ZStack {
                    Circle()
                        .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
                        .frame(width: 18, height: 18)
                    Image(systemName: "safari.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: Color.blue.opacity(0.35), radius: 2, y: 1)

            default:
                ZStack {
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .fill(sourceColor(track.source).opacity(0.9))
                        .frame(width: 18, height: 18)
                    Image(systemName: track.source.iconName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: sourceColor(track.source).opacity(0.35), radius: 2, y: 1)
            }
        }
    }

    private var nextEventLeading: some View {
        HStack(spacing: 5) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.cyan)
            Text(coordinator.calendarService.nextEvent?.countdownDescription ?? "Calendar")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 85, alignment: .leading)
        }
    }

    private var timerLeading: some View {
        HStack(spacing: 5) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.orange)
            Text(coordinator.timerService.formattedRemainingTime)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private var shelfLeading: some View {
        HStack(spacing: 5) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.blue)
            Text("\(coordinator.fileShelfService.items.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var clockLeading: some View {
        Text(Date(), style: .time)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
    }

    // MARK: - Trailing Subviews

    @ViewBuilder
    private var smartTrailingContent: some View {
        if coordinator.timerService.isRunning {
            CircularProgressRing(progress: coordinator.timerService.progress, lineWidth: 2, primaryColor: .orange)
                .frame(width: 14, height: 14)
        } else if coordinator.mediaService.currentTrack.isPlaying {
            AudioWaveformBarView(isPlaying: true, color: sourceColor(coordinator.mediaService.currentTrack.source))
        } else if coordinator.batteryService.hasBattery && coordinator.batteryService.isCharging {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.yellow)
        } else {
            if ScreenNotchDetector.detect().hasNotch {
                EmptyView()
            } else {
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var batteryTrailing: some View {
        HStack(spacing: 3) {
            Text("\(coordinator.batteryService.batteryLevel)%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            Image(systemName: coordinator.batteryService.isCharging ? "bolt.batteryblock.fill" : "battery.100")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(coordinator.batteryService.isCharging ? .yellow : .green)
        }
    }

    private var volumeTrailing: some View {
        HStack(spacing: 3) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.7))
            Text("\(Int(coordinator.systemControls.volume * 100))%")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.7))
        }
    }

    private var focusLeading: some View {
        HStack(spacing: 5) {
            Image(systemName: "flag.fill")
                .font(.system(size: 9))
                .foregroundColor(.yellow)

            Text(coordinator.focusService.currentFocusHeadline)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 80, alignment: .leading)
        }
    }

    private var focusTrailing: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.system(size: 9))
                .foregroundColor(.yellow)

            Text(coordinator.focusService.currentFocusHeadline)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .frame(maxWidth: 65, alignment: .trailing)
        }
    }

    private var weatherLeading: some View {
        HStack(spacing: 5) {
            Image(systemName: coordinator.weatherService.current?.sfSymbol ?? "sun.max.fill")
                .font(.system(size: 11))
                .foregroundColor(.yellow)
            Text(coordinator.weatherService.current?.formattedTemp ?? "--°")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var weatherTrailing: some View {
        HStack(spacing: 4) {
            Image(systemName: coordinator.weatherService.current?.sfSymbol ?? "cloud.sun.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow)
            Text(coordinator.weatherService.current?.formattedTemp ?? "--°")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private func sourceColor(_ source: MusicSource) -> Color {
        switch source {
        case .appleMusic: return Color(red: 0.98, green: 0.22, blue: 0.38)
        case .spotify: return Color(red: 0.11, green: 0.84, blue: 0.38)
        case .youtube: return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .chrome: return Color(red: 0.25, green: 0.55, blue: 1.0)
        case .safari: return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .webMedia: return Color(red: 0.0, green: 0.75, blue: 0.9)
        case .quickTime: return Color.blue
        case .vlc: return Color.orange
        case .system: return Color.white
        }
    }
}
