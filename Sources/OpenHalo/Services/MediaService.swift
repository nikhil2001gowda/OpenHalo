import Foundation
import AppKit
import Combine
import CoreAudio

@MainActor
public final class MediaService: ObservableObject {
    @Published public var currentTrack: MediaTrack = MediaTrack()
    @Published public var isAvailable: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    private var pollTimer: Timer?
    private var outputAudioDeviceID: AudioDeviceID = 0

    public nonisolated static func isAppRunning(bundleID: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    public nonisolated static func isAppInstalled(bundleID: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    public init() {
        setupDistributedNotificationObservers()
        setupAudioOutputListener()
        startPolling()
        checkActivePlayers()
    }

    deinit {
        pollTimer?.invalidate()
        progressTimer?.invalidate()
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

        // Spotify notification
        center.addObserver(
            self,
            selector: #selector(handleSpotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
    }

    private func setupAudioOutputListener() {
        var defaultOutputDevice = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &defaultOutputDevice
        )

        guard status == noErr && defaultOutputDevice != 0 else { return }
        self.outputAudioDeviceID = defaultOutputDevice

        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            defaultOutputDevice,
            &runningAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.checkActivePlayers()
            }
        }
    }

    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkActivePlayers()
            }
        }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    public nonisolated static func isSystemAudioOutputting() -> Bool {
        var defaultOutputDevice = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &defaultOutputDevice
        )

        guard status == noErr && defaultOutputDevice != 0 else { return false }

        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var runAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let err = AudioObjectGetPropertyData(defaultOutputDevice, &runAddress, 0, nil, &size, &isRunning)
        return (err == noErr && isRunning != 0)
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
        isAvailable = isPlaying
        updateProgressTimer()
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
        isAvailable = isPlaying
        updateProgressTimer()
    }

    private func updateProgressTimer() {
        progressTimer?.invalidate()
        if currentTrack.isPlaying {
            progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.currentTrack.isPlaying else { return }
                    if self.currentTrack.duration > 0 && self.currentTrack.position < self.currentTrack.duration {
                        self.currentTrack.position += 1.0
                    }
                }
            }
        }
    }

    // MARK: - Play / Pause Transport Controls

    public func togglePlayPause() {
        Task {
            switch currentTrack.source {
            case .appleMusic:
                if Self.isAppRunning(bundleID: "com.apple.Music") {
                    await AppleScriptRunner.run("tell application id \"com.apple.Music\" to playpause")
                }
            case .spotify:
                if Self.isAppRunning(bundleID: "com.spotify.client") {
                    await AppleScriptRunner.run("tell application id \"com.spotify.client\" to playpause")
                }
            default:
                // Universal macOS hardware media key (controls YouTube in Chrome, Safari, etc.)
                sendSystemMediaKey(key: 16)
            }

            currentTrack.playbackState = (currentTrack.playbackState == .playing) ? .paused : .playing
            updateProgressTimer()
        }
    }

    public func nextTrack() {
        Task {
            switch currentTrack.source {
            case .appleMusic:
                if Self.isAppRunning(bundleID: "com.apple.Music") {
                    await AppleScriptRunner.run("tell application id \"com.apple.Music\" to next track")
                }
            case .spotify:
                if Self.isAppRunning(bundleID: "com.spotify.client") {
                    await AppleScriptRunner.run("tell application id \"com.spotify.client\" to next track")
                }
            default:
                sendSystemMediaKey(key: 19)
            }
        }
    }

    public func previousTrack() {
        Task {
            switch currentTrack.source {
            case .appleMusic:
                if Self.isAppRunning(bundleID: "com.apple.Music") {
                    await AppleScriptRunner.run("tell application id \"com.apple.Music\" to previous track")
                }
            case .spotify:
                if Self.isAppRunning(bundleID: "com.spotify.client") {
                    await AppleScriptRunner.run("tell application id \"com.spotify.client\" to previous track")
                }
            default:
                sendSystemMediaKey(key: 20)
            }
        }
    }

    public func seek(to progressRatio: Double) {
        let targetSeconds = currentTrack.duration * progressRatio
        currentTrack.position = targetSeconds
        Task {
            if currentTrack.source == .spotify && Self.isAppRunning(bundleID: "com.spotify.client") {
                await AppleScriptRunner.run("tell application id \"com.spotify.client\" to set player position to \(targetSeconds)")
            } else if currentTrack.source == .appleMusic && Self.isAppRunning(bundleID: "com.apple.Music") {
                await AppleScriptRunner.run("tell application id \"com.apple.Music\" to set player position to \(targetSeconds)")
            }
        }
    }

    private func sendSystemMediaKey(key: Int32) {
        let downFlags = NSEvent.ModifierFlags(rawValue: 0xa00)
        let upFlags = NSEvent.ModifierFlags(rawValue: 0xb00)
        let dataDown = Int((key << 16) | (0xa << 8))
        let dataUp = Int((key << 16) | (0xb << 8))

        if let downEvent = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: downFlags, timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataDown, data2: -1)?.cgEvent {
            downEvent.post(tap: .cghidEventTap)
        }
        if let upEvent = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: upFlags, timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataUp, data2: -1)?.cgEvent {
            upEvent.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Multi-Source Media Detection (Music, Spotify, Chrome, Safari, YouTube, Web)

    public func checkActivePlayers() {
        Task.detached(priority: .userInitiated) {
            // 1. Check Apple Music
            if Self.isAppRunning(bundleID: "com.apple.Music") {
                let script = """
                tell application id "com.apple.Music"
                    if player state is playing then
                        return "Music|playing|" & (name of current track) & "|" & (artist of current track) & "|" & (duration of current track) & "|" & (player position)
                    end if
                end tell
                return "none"
                """
                if let output = await AppleScriptRunner.run(script), output != "none" {
                    await self.parseAndSetTrack(output: output)
                    return
                }
            }

            // 2. Check Spotify
            if Self.isAppRunning(bundleID: "com.spotify.client") {
                let script = """
                tell application id "com.spotify.client"
                    if player state is playing then
                        return "Spotify|playing|" & (name of current track) & "|" & (artist of current track) & "|" & ((duration of current track) / 1000) & "|" & (player position)
                    end if
                end tell
                return "none"
                """
                if let output = await AppleScriptRunner.run(script), output != "none" {
                    await self.parseAndSetTrack(output: output)
                    return
                }
            }

            // 3. Check Google Chrome (YouTube, Spotify Web, SoundCloud, Twitch, etc.)
            if Self.isAppRunning(bundleID: "com.google.Chrome") {
                let script = """
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            set u to URL of t
                            if u contains "youtube.com/watch" or u contains "music.youtube.com" or u contains "soundcloud.com" or u contains "spotify.com" or u contains "twitch.tv" or u contains "netflix.com" or u contains "hotstar.com" or u contains "primevideo.com" then
                                return (title of t) & "|||" & u & "|||Chrome"
                            end if
                        end repeat
                    end repeat
                end tell
                return "none"
                """
                if let output = await AppleScriptRunner.run(script), output != "none" {
                    await self.parseBrowserMedia(output: output, browserName: "Google Chrome")
                    return
                }
            }

            // 4. Check Safari
            if Self.isAppRunning(bundleID: "com.apple.Safari") {
                let script = """
                tell application "Safari"
                    repeat with w in windows
                        repeat with t in tabs of w
                            set u to URL of t
                            if u contains "youtube.com/watch" or u contains "music.youtube.com" or u contains "soundcloud.com" or u contains "spotify.com" or u contains "twitch.tv" or u contains "netflix.com" then
                                return (name of t) & "|||" & u & "|||Safari"
                            end if
                        end repeat
                    end repeat
                end tell
                return "none"
                """
                if let output = await AppleScriptRunner.run(script), output != "none" {
                    await self.parseBrowserMedia(output: output, browserName: "Safari")
                    return
                }
            }

            // 5. Check QuickTime Player
            if Self.isAppRunning(bundleID: "com.apple.QuickTimePlayerX") {
                let script = """
                tell application "QuickTime Player"
                    if exists (document 1) and (playing of document 1) then
                        return "QuickTime|" & (name of document 1)
                    end if
                end tell
                return "none"
                """
                if let output = await AppleScriptRunner.run(script), output != "none" {
                    let parts = output.components(separatedBy: "|")
                    let docName = parts.count > 1 ? parts[1] : "Video"
                    await self.setGenericPlayingTrack(title: docName, artist: "QuickTime Player", source: .quickTime)
                    return
                }
            }

            // 6. Generic Audio Check: Is system outputting audio?
            let isAudioOutputting = Self.isSystemAudioOutputting()
            if isAudioOutputting {
                // If audio is actively playing through speakers but neither Music/Spotify/Chrome tab was matched,
                // keep current track active or display System Audio
                await MainActor.run {
                    if !self.currentTrack.title.isEmpty && self.currentTrack.title != "No Media Playing" {
                        self.currentTrack.playbackState = .playing
                        self.isAvailable = true
                    }
                }
            } else {
                // Audio has stopped
                await MainActor.run {
                    if self.currentTrack.source != .appleMusic && self.currentTrack.source != .spotify {
                        self.currentTrack.playbackState = .paused
                    }
                }
            }
        }
    }

    private func parseBrowserMedia(output: String, browserName: String) {
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 2 else { return }

        var rawTitle = parts[0]
        let url = parts[1]

        var source: MusicSource = .webMedia
        var artist = browserName

        if url.contains("youtube.com") || url.contains("youtu.be") {
            source = .youtube
            artist = "YouTube • \(browserName)"
            // Clean title by removing standard " - YouTube" suffix
            if rawTitle.hasSuffix(" - YouTube") {
                rawTitle = String(rawTitle.dropLast(" - YouTube".count))
            } else if rawTitle.hasSuffix(" - YouTube Music") {
                rawTitle = String(rawTitle.dropLast(" - YouTube Music".count))
            }
        } else if url.contains("spotify.com") {
            source = .spotify
            artist = "Spotify Web"
        } else if url.contains("soundcloud.com") {
            source = .webMedia
            artist = "SoundCloud"
        } else if url.contains("netflix.com") {
            source = .webMedia
            artist = "Netflix"
        } else if url.contains("twitch.tv") {
            source = .webMedia
            artist = "Twitch"
        }

        self.currentTrack = MediaTrack(
            title: rawTitle.isEmpty ? "Media Playing" : rawTitle,
            artist: artist,
            album: "",
            duration: 0,
            position: 0,
            playbackState: .playing,
            source: source
        )
        self.isAvailable = true
        self.updateProgressTimer()
    }

    private func setGenericPlayingTrack(title: String, artist: String, source: MusicSource) {
        self.currentTrack = MediaTrack(
            title: title,
            artist: artist,
            album: "",
            duration: 0,
            position: 0,
            playbackState: .playing,
            source: source
        )
        self.isAvailable = true
        self.updateProgressTimer()
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
}
