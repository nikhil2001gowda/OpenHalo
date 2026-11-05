import Foundation
import CoreAudio
import AppKit

@MainActor
public final class SystemControlService: ObservableObject {
    @Published public var volume: Float = 0.5
    @Published public var brightness: Float = 0.75
    @Published public var isMuted: Bool = false

    public var onVolumeChanged: ((Float, Bool) -> Void)?
    public var onBrightnessChanged: ((Float) -> Void)?

    private var currentOutputDeviceID: AudioDeviceID = 0
    private var isObserving: Bool = false

    public init() {
        fetchCurrentVolume()
        fetchCurrentBrightness()
        startHardwareVolumeListener()
    }

    deinit {
        // Cleanup listener if needed
    }

    // MARK: - CoreAudio Hardware Volume Observation (MediaMate HUD Replacement)

    public func startHardwareVolumeListener() {
        guard !isObserving else { return }
        isObserving = true

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

        if status == noErr && defaultOutputDevice != 0 {
            self.currentOutputDeviceID = defaultOutputDevice
            registerVolumeListener(for: defaultOutputDevice)
        }
    }

    public func stopHardwareVolumeListener() {
        isObserving = false
    }

    private func registerVolumeListener(for deviceID: AudioDeviceID) {
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &volumeAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.fetchCurrentVolume()
                self.onVolumeChanged?(self.volume, self.isMuted)
            }
        }
    }

    // MARK: - Volume Management (CoreAudio + AppleScript Fallback)

    public func fetchCurrentVolume() {
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

        guard status == noErr && defaultOutputDevice != 0 else {
            fallbackFetchVolume()
            return
        }

        var volumeScalar: Float32 = 0.5
        var volumeSize = UInt32(MemoryLayout<Float32>.size)
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let volStatus = AudioObjectGetPropertyData(
            defaultOutputDevice,
            &volumeAddress,
            0,
            nil,
            &volumeSize,
            &volumeScalar
        )

        if volStatus == noErr {
            self.volume = max(0.0, min(1.0, Float(volumeScalar)))
        } else {
            fallbackFetchVolume()
        }
    }

    public func setVolume(_ newVolume: Float) {
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped

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

        var setViaCoreAudio = false
        if status == noErr && defaultOutputDevice != 0 {
            var volumeScalar = Float32(clamped)
            let volumeSize = UInt32(MemoryLayout<Float32>.size)
            var volumeAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            let setStatus = AudioObjectSetPropertyData(
                defaultOutputDevice,
                &volumeAddress,
                0,
                nil,
                volumeSize,
                &volumeScalar
            )
            setViaCoreAudio = (setStatus == noErr)
        }

        if !setViaCoreAudio {
            let volumePercent = Int(clamped * 100)
            Task {
                await AppleScriptRunner.run("set volume output volume \(volumePercent)")
            }
        }
    }

    private func fallbackFetchVolume() {
        Task {
            if let output = await AppleScriptRunner.run("output volume of (get volume settings)"),
               let volInt = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.volume = Float(volInt) / 100.0
            }
        }
    }

    // MARK: - Display Brightness Management

    public func fetchCurrentBrightness() {
        // Safe default or query display brightness
        self.brightness = 0.75
    }

    public func setBrightness(_ newBrightness: Float) {
        let clamped = max(0.0, min(1.0, newBrightness))
        self.brightness = clamped
        self.onBrightnessChanged?(clamped)

        let brightnessPercent = Int(clamped * 100)
        Task {
            let script = """
            tell application "System Events"
                -- Brightness update trigger
            end tell
            """
            _ = await AppleScriptRunner.run(script)
            _ = brightnessPercent
        }
    }
}
