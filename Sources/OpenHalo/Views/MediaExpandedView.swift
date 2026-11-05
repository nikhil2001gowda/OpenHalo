import SwiftUI

public struct MediaExpandedView: View {
    @ObservedObject var mediaService: MediaService
    @ObservedObject var systemControls: SystemControlService

    @MainActor
    public init(mediaService: MediaService, systemControls: SystemControlService) {
        self.mediaService = mediaService
        self.systemControls = systemControls
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Track Info & Artwork
            HStack(spacing: 14) {
                // Artwork or App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                        .frame(width: 46, height: 46)

                    Image(systemName: mediaService.currentTrack.source == .spotify ? "music.note" : "apple.logo")
                        .font(.system(size: 22))
                        .foregroundColor(mediaService.currentTrack.source == .spotify ? .green : .pink)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )

                // Title & Artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(mediaService.currentTrack.title.isEmpty ? "No Media Playing" : mediaService.currentTrack.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if mediaService.currentTrack.title.isEmpty {
                        HStack(spacing: 6) {
                            Button(action: {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 9))
                                    Text("Music")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.pink)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.pink.opacity(0.2))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                if let spotifyURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
                                    NSWorkspace.shared.open(spotifyURL)
                                } else {
                                    NSWorkspace.shared.open(URL(string: "https://open.spotify.com")!)
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 9))
                                    Text("Spotify")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    } else {
                        Text(mediaService.currentTrack.artist)
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
                if mediaService.currentTrack.isPlaying {
                    AudioWaveformBarView(isPlaying: true, color: .green)
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

                            Image(systemName: mediaService.currentTrack.isPlaying ? "pause.fill" : "play.fill")
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

                // System Volume Slider
                HStack(spacing: 6) {
                    Image(systemName: systemControls.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.7))

                    Slider(
                        value: Binding(
                            get: { systemControls.volume },
                            set: { systemControls.setVolume($0) }
                        ),
                        in: 0...1
                    )
                    .frame(width: 90)
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
