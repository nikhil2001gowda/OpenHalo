import Foundation
import AppKit
import Combine
import CoreAudio

@MainActor
public final class MediaService: ObservableObject {
    @Published public var currentTrack: MediaTrack = MediaTrack()
    @Published public var isAvailable: Bool = false
    @Published public var upcomingQueue: [PlayingNextTrack] = []

    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    private var pollTimer: Timer?
    private var outputAudioDeviceID: AudioDeviceID = 0
    private var pausedSince: Date? = nil

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
        // Eco-friendly 5.0s polling with 2.5s system tolerance: CoreAudio hardware listener handles instant playback start/stop
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkActivePlayers()
            }
        }
        pollTimer?.tolerance = 2.5
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
        Task { [weak self] in
            await self?.fetchUpcomingQueue()
        }
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
        Task { [weak self] in
            await self?.fetchUpcomingQueue()
        }
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
            progressTimer?.tolerance = 0.5
        }
    }

    // MARK: - Play / Pause Transport Controls

    public func togglePlayPause() {
        Task {
            guard !currentTrack.title.isEmpty && currentTrack.title != "No Media Playing" && currentTrack.title != "Unknown Title" else {
                // If nothing is playing, launch Music app cleanly without toggling fake playing state
                if Self.isAppInstalled(bundleID: "com.apple.Music") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
                }
                return
            }

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

    public func openSourceApp() {
        switch currentTrack.source {
        case .appleMusic:
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
                NSWorkspace.shared.open(url)
            } else {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
            }
        case .spotify:
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
                NSWorkspace.shared.open(url)
            }
        case .chrome:
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
                NSWorkspace.shared.open(url)
            }
        case .safari:
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                NSWorkspace.shared.open(url)
            }
        default:
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
                NSWorkspace.shared.open(url)
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

    // MARK: - Playing Next Queue Fetcher (Apple Music & Spotify)

    public func fetchUpcomingQueue() async {
        guard currentTrack.isPlaying else {
            self.upcomingQueue = []
            return
        }

        if currentTrack.source == .appleMusic && Self.isAppRunning(bundleID: "com.apple.Music") {
            let script = """
            tell application id "com.apple.Music"
                if player state is playing then
                    try
                        set curIndex to index of current track
                        set allTracks to (tracks of current playlist)
                        set totalCount to count of allTracks
                        set output to ""
                        set collected to 0
                        repeat with i from (curIndex + 1) to totalCount
                            if collected >= 3 then exit repeat
                            set trk to item i of allTracks
                            set output to output & (name of trk) & "---" & (artist of trk) & "---" & (duration of trk as integer) & "\\n"
                            set collected to collected + 1
                        end repeat
                        return output
                    end try
                end if
            end tell
            return ""
            """
            if let result = await AppleScriptRunner.run(script), !result.isEmpty {
                let lines = result.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                var items: [PlayingNextTrack] = []
                for line in lines {
                    let parts = line.components(separatedBy: "---")
                    if parts.count >= 2 {
                        let title = parts[0].trimmingCharacters(in: .whitespaces)
                        let artist = parts[1].trimmingCharacters(in: .whitespaces)
                        let dur = Double(parts.count >= 3 ? parts[2].trimmingCharacters(in: .whitespaces) : "0") ?? 0
                        items.append(PlayingNextTrack(title: title, artist: artist, duration: dur, source: .appleMusic))
                    }
                }
                self.upcomingQueue = items
            }
        }
    }

    // MARK: - Multi-Source Media Detection (Music, Spotify, Chrome, Safari, YouTube, Web)

    public func checkActivePlayers() {
        Task.detached(priority: .utility) {
            let isSystemAudioActive = Self.isSystemAudioOutputting()

            // Eco Guard: If system audio hardware is completely silent, skip heavy AppleScript processes
            guard isSystemAudioActive else {
                await MainActor.run {
                    self.pausedSince = nil
                    if self.currentTrack.playbackState == .playing {
                        self.currentTrack.playbackState = .paused
                        self.isAvailable = false
                        self.updateProgressTimer()
                    }
                }
                return
            }

            // 1. Check Apple Music
            if Self.isAppRunning(bundleID: "com.apple.Music") {
                let script = """
                tell application id "com.apple.Music"
                    if exists current track then
                        set pState to player state as string
                        return "Music|" & pState & "|" & (name of current track) & "|" & (artist of current track) & "|" & (duration of current track) & "|" & (player position)
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
                    if exists current track then
                        set pState to player state as string
                        return "Spotify|" & pState & "|" & (name of current track) & "|" & (artist of current track) & "|" & ((duration of current track) / 1000) & "|" & (player position)
                    end if
                end tell
                return "none"
                """
                if let output = await AppleScriptRunner.run(script), output != "none" {
                    await self.parseAndSetTrack(output: output)
                    return
                }
            }

            // 3. Check Web Browsers (Chrome, Brave, Arc, Edge, Safari) for YouTube, Spotify Web, etc.
            let browserConfigs: [(bundleID: String, appName: String)] = [
                ("com.google.Chrome", "Google Chrome"),
                ("com.brave.Browser", "Brave Browser"),
                ("company.thebrowser.Arc", "Arc"),
                ("com.microsoft.edgemac", "Microsoft Edge"),
                ("com.apple.Safari", "Safari")
            ]

            for config in browserConfigs {
                if Self.isAppRunning(bundleID: config.bundleID) {
                    let script = config.appName == "Safari" ? """
                    tell application "Safari"
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "youtube.com/watch" or u contains "music.youtube.com" or u contains "soundcloud.com" or u contains "spotify.com" or u contains "twitch.tv" or u contains "netflix.com" then
                                    return (name of t) & "|||" & u & "|||\(config.appName)"
                                end if
                            end repeat
                        end repeat
                    end tell
                    return "none"
                    """ : """
                    tell application "\(config.appName)"
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "youtube.com/watch" or u contains "music.youtube.com" or u contains "soundcloud.com" or u contains "spotify.com" or u contains "twitch.tv" or u contains "netflix.com" or u contains "hotstar.com" or u contains "primevideo.com" then
                                    return (title of t) & "|||" & u & "|||\(config.appName)"
                                end if
                            end repeat
                        end repeat
                    end tell
                    return "none"
                    """

                    if let output = await AppleScriptRunner.run(script), output != "none" {
                        await self.parseBrowserMedia(output: output, browserName: config.appName, isAudible: isSystemAudioActive)
                        return
                    }
                }
            }

            // 4. Check QuickTime Player
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
                    await self.setGenericPlayingTrack(title: docName, artist: "QuickTime Player", source: .quickTime, isPlaying: isSystemAudioActive)
                    return
                }
            }

            // 5. If no active media stream was detected in any player/browser, clear media state so Island returns to notch width
            await MainActor.run {
                self.pausedSince = nil
                if self.currentTrack.source != .appleMusic && self.currentTrack.source != .spotify {
                    if !self.currentTrack.title.isEmpty {
                        self.currentTrack = MediaTrack()
                        self.isAvailable = false
                        self.updateProgressTimer()
                    }
                } else if self.currentTrack.playbackState == .playing && !isSystemAudioActive {
                    self.currentTrack.playbackState = .paused
                    self.isAvailable = false
                    self.updateProgressTimer()
                }
            }
        }
    }

    private func parseBrowserMedia(output: String, browserName: String, isAudible: Bool) {
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 2 else { return }

        var rawTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let url = parts[1]

        var source: MusicSource = .webMedia
        var artist = browserName

        if url.contains("youtube.com") || url.contains("youtu.be") {
            source = .youtube
            artist = "YouTube"
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

        let isPlaying = isAudible

        if !isPlaying {
            if pausedSince == nil {
                pausedSince = Date()
            }
            // If paused for more than 40 seconds, clear the track so it doesn't linger
            if let pausedAt = pausedSince, Date().timeIntervalSince(pausedAt) > 40 {
                self.currentTrack = MediaTrack()
                self.isAvailable = false
                self.updateProgressTimer()
                return
            }
        } else {
            pausedSince = nil
        }

        self.currentTrack = MediaTrack(
            title: rawTitle.isEmpty ? "Media Playing" : rawTitle,
            artist: artist,
            album: "",
            duration: 0,
            position: 0,
            playbackState: isPlaying ? .playing : .paused,
            source: source
        )
        self.isAvailable = isPlaying
        self.updateProgressTimer()
    }

    private func setGenericPlayingTrack(title: String, artist: String, source: MusicSource, isPlaying: Bool = true) {
        self.currentTrack = MediaTrack(
            title: title,
            artist: artist,
            album: "",
            duration: 0,
            position: 0,
            playbackState: isPlaying ? .playing : .paused,
            source: source
        )
        self.isAvailable = isPlaying
        self.updateProgressTimer()
    }

    private func parseAndSetTrack(output: String) {
        let parts = output.components(separatedBy: "|")
        if parts.count >= 6 {
            let source: MusicSource = (parts[0] == "Spotify") ? .spotify : .appleMusic
            let stateStr = parts[1].lowercased()
            let isPlaying = (stateStr == "playing")
            let title = parts[2]
            let artist = parts[3]
            let duration = Double(parts[4]) ?? 0
            let position = Double(parts[5]) ?? 0

            if !isPlaying {
                if pausedSince == nil {
                    pausedSince = Date()
                }
                if let pausedAt = pausedSince, Date().timeIntervalSince(pausedAt) > 40 {
                    self.currentTrack = MediaTrack()
                    self.isAvailable = false
                    self.updateProgressTimer()
                    return
                }
            } else {
                pausedSince = nil
            }

            self.currentTrack = MediaTrack(
                title: title,
                artist: artist,
                album: "",
                duration: duration,
                position: position,
                playbackState: isPlaying ? .playing : .paused,
                source: source
            )
            self.isAvailable = isPlaying
            self.updateProgressTimer()
        }
    }
}
