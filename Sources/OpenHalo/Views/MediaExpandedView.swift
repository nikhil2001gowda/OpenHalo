import SwiftUI

public struct MediaExpandedView: View {
    @ObservedObject var mediaService: MediaService
    @ObservedObject var systemControls: SystemControlService

    @MainActor
    public init(mediaService: MediaService, systemControls: SystemControlService) {
        self.mediaService = mediaService
        self.systemControls = systemControls
    }

    private var isTrackActive: Bool {
        !mediaService.currentTrack.title.isEmpty &&
        mediaService.currentTrack.title != "Unknown Title" &&
        mediaService.currentTrack.title != "No Media Playing"
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Track Info & Artwork
            HStack(spacing: 14) {
                // Artwork or App Icon
                Button(action: {
                    mediaService.openSourceApp()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                            .frame(width: 46, height: 46)

                        Image(systemName: isTrackActive ? mediaService.currentTrack.source.iconName : "music.note")
                            .font(.system(size: 22))
                            .foregroundColor(sourceColor(mediaService.currentTrack.source))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help(isTrackActive ? "Open \(mediaService.currentTrack.source.rawValue)" : "Open Music")

                // Title & Artist
                VStack(alignment: .leading, spacing: 2) {
                    if isTrackActive {
                        AtollMarqueeText(
                            mediaService.currentTrack.title,
                            font: .system(size: 13, weight: .semibold),
                            textColor: .white,
                            frameWidth: 190
                        )
                    } else {
                        Text("No Media Playing")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    if !isTrackActive {
                        Text("Auto-detects any media app when playing")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if MediaService.isAppInstalled(bundleID: "com.apple.Music") {
                                Button(action: {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "apple.logo")
                                            .font(.system(size: 9))
                                        Text("Open Music")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .foregroundColor(.pink)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.pink.opacity(0.2))
                                    .cornerRadius(5)
                                }
                                .buttonStyle(.plain)
                            }

                            if MediaService.isAppInstalled(bundleID: "com.spotify.client") {
                                Button(action: {
                                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 9))
                                        Text("Open Spotify")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(5)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                    } else {
                        Text(mediaService.currentTrack.artist.isEmpty || mediaService.currentTrack.artist == "Unknown Artist" ? "Apple Music" : mediaService.currentTrack.artist)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.65))
                            .lineLimit(1)

                        if !mediaService.currentTrack.album.isEmpty {
                            Text(mediaService.currentTrack.album)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Playing Waveform
                if isTrackActive && mediaService.currentTrack.isPlaying {
                    AudioWaveformBarView(isPlaying: true, color: sourceColor(mediaService.currentTrack.source))
                        .padding(.trailing, 4)
                }
            }

            // Progress Scrubber
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 3.5)

                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * CGFloat(mediaService.currentTrack.progress), height: 3.5)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let ratio = Double(value.location.x / geo.size.width)
                                mediaService.seek(to: ratio)
                            }
                    )
                }
                .frame(height: 3.5)

                HStack {
                    Text(mediaService.currentTrack.formattedPosition)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))

                    Spacer()

                    Text(mediaService.currentTrack.formattedDuration)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }

            // Controls & Volume Slider
            HStack(spacing: 16) {
                // Playback Controls
                HStack(spacing: 16) {
                    Button(action: { mediaService.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: { mediaService.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)

                            Image(systemName: (isTrackActive && mediaService.currentTrack.isPlaying) ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { mediaService.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Atoll Tactile Volume Capsule Slider
                AtollVolumeCapsuleSlider(
                    value: Binding(
                        get: { Double(systemControls.volume) },
                        set: { systemControls.setVolume(Float($0)) }
                    ),
                    tint: .white,
                    compact: true
                )
                .frame(width: 130)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func sourceColor(_ source: MusicSource) -> Color {
        switch source {
        case .appleMusic: return .pink
        case .spotify: return .green
        case .youtube: return .red
        case .chrome: return .blue
        case .safari: return .blue
        case .webMedia: return .cyan
        case .quickTime: return .blue
        case .vlc: return .orange
        case .system: return .white
        }
    }
}
