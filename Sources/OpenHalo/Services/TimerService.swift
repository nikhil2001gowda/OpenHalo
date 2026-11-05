import Foundation
import Combine

public struct TimerPreset: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let seconds: TimeInterval

    public init(title: String, seconds: TimeInterval) {
        self.id = title
        self.title = title
        self.seconds = seconds
    }
}

@MainActor
public final class TimerService: ObservableObject {
    @Published public var isRunning: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var remainingSeconds: TimeInterval = 0
    @Published public var totalSeconds: TimeInterval = 0
    @Published public var activePresetName: String? = nil
    @Published public var isFinishedAlert: Bool = false

    private var timer: Timer?
    private var targetEndDate: Date?

    public static nonisolated let defaultPresets: [TimerPreset] = [
        TimerPreset(title: "1m", seconds: 60),
        TimerPreset(title: "5m", seconds: 300),
        TimerPreset(title: "15m", seconds: 900),
        TimerPreset(title: "25m (Pomo)", seconds: 1500)
    ]

    public init() {}

    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(max((totalSeconds - remainingSeconds) / totalSeconds, 0.0), 1.0)
    }

    public var formattedRemainingTime: String {
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    public func start(duration: TimeInterval, presetName: String? = nil) {
        stop()
        self.totalSeconds = duration
        self.remainingSeconds = duration
        self.activePresetName = presetName
        self.isRunning = true
        self.isPaused = false
        self.isFinishedAlert = false
        self.targetEndDate = Date().addingTimeInterval(duration)

        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    public func pause() {
        guard isRunning && !isPaused else { return }
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    public func resume() {
        guard isRunning && isPaused else { return }
        isPaused = false
        targetEndDate = Date().addingTimeInterval(remainingSeconds)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        remainingSeconds = 0
        totalSeconds = 0
        activePresetName = nil
        targetEndDate = nil
    }

    public func dismissAlert() {
        isFinishedAlert = false
    }

    private func tick() {
        guard let target = targetEndDate else { return }
        let now = Date()
        let diff = target.timeIntervalSince(now)

        if diff <= 0 {
            remainingSeconds = 0
            stop()
            isFinishedAlert = true
            SoundEffectManager.playTimerDone()
        } else {
            remainingSeconds = ceil(diff)
        }
    }
}
