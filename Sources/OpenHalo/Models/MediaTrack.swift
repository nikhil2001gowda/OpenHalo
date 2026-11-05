import Foundation
import AppKit

public enum MusicSource: String, Sendable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case system = "System"
}

public enum PlaybackState: String, Sendable {
    case playing
    case paused
    case stopped
}

public struct MediaTrack: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var position: TimeInterval
    public var playbackState: PlaybackState
    public var source: MusicSource
    public var artworkData: Data?

    public init(
        title: String = "",
        artist: String = "",
        album: String = "",
        duration: TimeInterval = 0,
        position: TimeInterval = 0,
        playbackState: PlaybackState = .stopped,
        source: MusicSource = .system,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.playbackState = playbackState
        self.source = source
        self.artworkData = artworkData
    }

    public var isPlaying: Bool {
        playbackState == .playing
    }

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    public var formattedPosition: String {
        formatTime(position)
    }

    public var formattedDuration: String {
        formatTime(duration)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

