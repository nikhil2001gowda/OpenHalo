import Foundation
import AppKit
import Combine

@MainActor
public final class MediaService: ObservableObject {
    @Published public var currentTrack: MediaTrack = MediaTrack()
    @Published public var isAvailable: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?

    public static func isAppRunning(bundleID: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    public static func isAppInstalled(bundleID: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    public init() {
        setupDistributedNotificationObservers()
        checkActivePlayers()
    }

    private func setupDistributedNotificationObservers() {
        let center = DistributedNotificationCenter.default()

        // Apple Music notification
        center.addObserver(
            self,
            selector: #selector(handleAppleMusicNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )

        // Spotify notification (auto-listens, will trigger automatically if user installs/runs Spotify)
        center.addObserver(
            self,
            selector: #selector(handleSpotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
    }

    @objc private func handleAppleMusicNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        let stateString = userInfo["Player State"] as? String ?? ""
        let isPlaying = (stateString.lowercased() == "playing")

        let trackName = userInfo["Name"] as? String ?? "Unknown Title"
        let artist = userInfo["Artist"] as? String ?? "Unknown Artist"
        let album = userInfo["Album"] as? String ?? ""
        let totalTimeMS = (userInfo["Total Time"] as? NSNumber)?.doubleValue ?? 0
        let duration = totalTimeMS / 1000.0

        currentTrack = MediaTrack(
            title: trackName,
            artist: artist,
            album: album,
            duration: duration,
            position: 0,
            playbackState: isPlaying ? .playing : .paused,
            source: .appleMusic,
            artworkData: nil
        )
        isAvailable = true

        updateProgressTimer()
        fetchAppleMusicArtwork()
    }

    @objc private func handleSpotifyNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        let stateString = userInfo["Player State"] as? String ?? ""
        let isPlaying = (stateString.lowercased() == "playing")

        let trackName = userInfo["Name"] as? String ?? "Unknown Title"
        let artist = userInfo["Artist"] as? String ?? "Unknown Artist"
        let album = userInfo["Album"] as? String ?? ""
        let duration = (userInfo["Duration"] as? NSNumber)?.doubleValue ?? 0
        let position = (userInfo["Playback Position"] as? NSNumber)?.doubleValue ?? 0

        currentTrack = MediaTrack(
            title: trackName,
            artist: artist,
            album: album,
            duration: duration,
            position: position,
            playbackState: isPlaying ? .playing : .paused,
            source: .spotify,
            artworkData: nil
        )
        isAvailable = true

        updateProgressTimer()
    }

    private func updateProgressTimer() {
        progressTimer?.invalidate()
        if currentTrack.isPlaying {
            progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.currentTrack.isPlaying else { return }
                    if self.currentTrack.position < self.currentTrack.duration {
                        self.currentTrack.position += 1.0
                    }
                }
            }
        }
    }

    public func togglePlayPause() {
        Task {
            let isSpotifyRunning = Self.isAppRunning(bundleID: "com.spotify.client")
            let isMusicRunning = Self.isAppRunning(bundleID: "com.apple.Music")

            if currentTrack.source == .spotify && isSpotifyRunning {
                await AppleScriptRunner.run("tell application id \"com.spotify.client\" to playpause")
            } else if isMusicRunning {
                await AppleScriptRunner.run("tell application id \"com.apple.Music\" to playpause")
            } else if isSpotifyRunning {
                await AppleScriptRunner.run("tell application id \"com.spotify.client\" to playpause")
            } else if Self.isAppInstalled(bundleID: "com.apple.Music") {
                // If neither is running, launch built-in Music cleanly via NSWorkspace (never prompts!)
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
            }

            // Toggle local optimistic state
            currentTrack.playbackState = (currentTrack.playbackState == .playing) ? .paused : .playing
            updateProgressTimer()
        }
    }

    public func nextTrack() {
        Task {
            if currentTrack.source == .spotify && Self.isAppRunning(bundleID: "com.spotify.client") {
                await AppleScriptRunner.run("tell application id \"com.spotify.client\" to next track")
            } else if Self.isAppRunning(bundleID: "com.apple.Music") {
                await AppleScriptRunner.run("tell application id \"com.apple.Music\" to next track")
            }
        }
    }

    public func previousTrack() {
        Task {
            if currentTrack.source == .spotify && Self.isAppRunning(bundleID: "com.spotify.client") {
                await AppleScriptRunner.run("tell application id \"com.spotify.client\" to previous track")
            } else if Self.isAppRunning(bundleID: "com.apple.Music") {
                await AppleScriptRunner.run("tell application id \"com.apple.Music\" to previous track")
            }
        }
    }

    public func seek(to progressRatio: Double) {
        let targetSeconds = currentTrack.duration * progressRatio
        currentTrack.position = targetSeconds
        Task {
            if currentTrack.source == .spotify && Self.isAppRunning(bundleID: "com.spotify.client") {
                await AppleScriptRunner.run("tell application id \"com.spotify.client\" to set player position to \(targetSeconds)")
            } else if Self.isAppRunning(bundleID: "com.apple.Music") {
                await AppleScriptRunner.run("tell application id \"com.apple.Music\" to set player position to \(targetSeconds)")
            }
        }
    }

    private func checkActivePlayers() {
        Task {
            // ONLY query applications that are currently active in process table
            // This guarantees macOS NEVER pops up a "Where is <App>?" dialog
            let isMusicRunning = Self.isAppRunning(bundleID: "com.apple.Music")
            let isSpotifyRunning = Self.isAppRunning(bundleID: "com.spotify.client")

            if isMusicRunning {
                let script = """
                tell application id "com.apple.Music"
                    if player state is playing then
                        return "Music|playing|" & (name of current track) & "|" & (artist of current track) & "|" & (duration of current track) & "|" & (player position)
                    end if
                end tell
                return "none"
                """
                if let output = await AppleScriptRunner.run(script), output != "none" {
                    self.parseAndSetTrack(output: output)
                    return
                }
            }

            if isSpotifyRunning {
                let script = """
                tell application id "com.spotify.client"
                    if player state is playing then
                        return "Spotify|playing|" & (name of current track) & "|" & (artist of current track) & "|" & ((duration of current track) / 1000) & "|" & (player position)
                    end if
                end tell
                return "none"
                """
                if let output = await AppleScriptRunner.run(script), output != "none" {
                    self.parseAndSetTrack(output: output)
                    return
                }
            }
        }
    }

    private func parseAndSetTrack(output: String) {
        let parts = output.components(separatedBy: "|")
        if parts.count >= 6 {
            let source: MusicSource = (parts[0] == "Spotify") ? .spotify : .appleMusic
            let title = parts[2]
            let artist = parts[3]
            let duration = Double(parts[4]) ?? 0
            let position = Double(parts[5]) ?? 0

            self.currentTrack = MediaTrack(
                title: title,
                artist: artist,
                album: "",
                duration: duration,
                position: position,
                playbackState: .playing,
                source: source
            )
            self.isAvailable = true
            self.updateProgressTimer()
        }
    }

    private func fetchAppleMusicArtwork() {
        guard Self.isAppRunning(bundleID: "com.apple.Music") else { return }
        Task {
            let script = """
            tell application id "com.apple.Music"
                if player state is playing then
                    try
                        set rawData to raw data of artwork 1 of current track
                        return "has_artwork"
                    end try
                end if
            end tell
            return "none"
            """
            _ = await AppleScriptRunner.run(script)
        }
    }
}
