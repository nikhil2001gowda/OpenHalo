import Foundation

public enum PillLeadingSlot: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto (Smart Priority)"
    case nowPlaying = "Now Playing"
    case nextEvent = "Next Meeting"
    case focusTask = "Focus Task Ticker"
    case weather = "Live Weather"
    case timer = "Timer Countdown"
    case clock = "Current Clock"

    public var id: String { rawValue }
}

public enum PillTrailingSlot: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto (Waveform / Mic / Battery)"
    case audioWaveform = "Audio Waveform"
    case battery = "Battery Level"
    case weather = "Live Weather"
    case micIndicator = "Microphone Security"
    case volume = "Volume Level"
    case focusTask = "Focus Ticker"
    case none = "None (Minimal)"

    public var id: String { rawValue }
}
