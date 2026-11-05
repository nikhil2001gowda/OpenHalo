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
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 6, height: 6)
        }
    }

    private var nowPlayingLeading: some View {
        HStack(spacing: 6) {
            Image(systemName: coordinator.mediaService.currentTrack.source == .spotify ? "music.note" : "apple.logo")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.green)
            Text(coordinator.mediaService.currentTrack.title.isEmpty ? "Now Playing" : coordinator.mediaService.currentTrack.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 85, alignment: .leading)
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
        if coordinator.mediaService.currentTrack.isPlaying {
            AudioWaveformBarView(isPlaying: true, color: .green)
        } else if coordinator.batteryService.hasBattery && coordinator.batteryService.isCharging {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.yellow)
        } else {
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 6, height: 6)
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
}
