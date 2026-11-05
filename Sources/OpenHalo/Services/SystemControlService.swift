import Foundation
import CoreAudio
import AppKit
import CoreGraphics

@MainActor
public final class SystemControlService: ObservableObject {
    @Published public var volume: Float = 0.5
    @Published public var brightness: Float = 0.5
    @Published public var isMuted: Bool = false

    public var onVolumeChanged: ((Float, Bool) -> Void)?
    public var onBrightnessChanged: ((Float) -> Void)?

    private var currentOutputDeviceID: AudioDeviceID = 0
    private var syncTimer: Timer?
    private var lastUserAdjustmentDate: Date = .distantPast

    // Private DisplayServices Dynamic Function Pointers (macOS System Settings perceived brightness)
    private typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private var getBrightnessPointer: GetBrightnessFunc?
    private var setBrightnessPointer: SetBrightnessFunc?

    public init() {
        setupDisplayServices()
        fetchCurrentVolume()
        fetchCurrentBrightness()
        setupDefaultDeviceListener()
        startHardwareVolumeListener()
        startPeriodicSync()
    }

    deinit {
        syncTimer?.invalidate()
    }

    // MARK: - DisplayServices Initialization

    private func setupDisplayServices() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) {
            // Prefer user-perceived DisplayServicesGetBrightness/SetBrightness (exact match with macOS Control Center & F1/F2 keys)
            if let getSym = dlsym(handle, "DisplayServicesGetBrightness") ?? dlsym(handle, "DisplayServicesGetLinearBrightness") {
                getBrightnessPointer = unsafeBitCast(getSym, to: GetBrightnessFunc.self)
            }
            if let setSym = dlsym(handle, "DisplayServicesSetBrightness") ?? dlsym(handle, "DisplayServicesSetLinearBrightness") {
                setBrightnessPointer = unsafeBitCast(setSym, to: SetBrightnessFunc.self)
            }
        }
    }

    // MARK: - Periodic Hardware Sync (Catches F1/F2 & F11/F12 Keyboard Keys)

    public func startPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.syncHardwareState()
            }
        }
    }

    public func stopHardwareVolumeListener() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    private func syncHardwareState() {
        // Debounce: If user is actively dragging the slider, do not overwrite mid-drag
        guard Date().timeIntervalSince(lastUserAdjustmentDate) > 1.2 else { return }

        // 1. Sync Brightness
        if let fn = getBrightnessPointer {
            var currentHardwareB: Float = 0.0
            if fn(CGMainDisplayID(), &currentHardwareB) == 0 {
                let clamped = max(0.0, min(1.0, currentHardwareB))
                if abs(clamped - self.brightness) > 0.02 {
                    self.brightness = clamped
                    self.onBrightnessChanged?(clamped)
                }
            }
        }

        // 2. Sync Volume
        let currentHardwareVol = getHardwareVolumeScalar()
        if abs(currentHardwareVol - self.volume) > 0.02 {
            self.volume = currentHardwareVol
            self.onVolumeChanged?(currentHardwareVol, self.isMuted)
        }
    }

    // MARK: - Display Brightness Management (Real-time Bidirectional)

    public func fetchCurrentBrightness() {
        if let fn = getBrightnessPointer {
            var currentHardwareB: Float = 0.5
            if fn(CGMainDisplayID(), &currentHardwareB) == 0 {
                self.brightness = max(0.0, min(1.0, currentHardwareB))
                return
            }
        }
        self.brightness = 0.5
    }

    public func setBrightness(_ newBrightness: Float) {
        lastUserAdjustmentDate = Date()
        let clamped = max(0.0, min(1.0, newBrightness))
        self.brightness = clamped

        if let fn = setBrightnessPointer {
            _ = fn(CGMainDisplayID(), clamped)
        }

        self.onBrightnessChanged?(clamped)
    }

    // MARK: - Volume Management (Real-time Bidirectional)

    private func setupDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.startHardwareVolumeListener()
                self.fetchCurrentVolume()
            }
        }
    }

    public func startHardwareVolumeListener() {
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

            var volumeAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectAddPropertyListenerBlock(
                defaultOutputDevice,
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
    }

    private func getHardwareVolumeScalar() -> Float {
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

        guard status == noErr && defaultOutputDevice != 0 else { return self.volume }

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
            return max(0.0, min(1.0, Float(volumeScalar)))
        }

        // Fallback channel 1
        var leftAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 1
        )
        if AudioObjectGetPropertyData(defaultOutputDevice, &leftAddress, 0, nil, &volumeSize, &volumeScalar) == noErr {
            return max(0.0, min(1.0, Float(volumeScalar)))
        }

        return self.volume
    }

    public func fetchCurrentVolume() {
        self.volume = getHardwareVolumeScalar()
    }

    public func setVolume(_ newVolume: Float) {
        lastUserAdjustmentDate = Date()
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

        if status == noErr && defaultOutputDevice != 0 {
            var volumeScalar = Float32(clamped)
            let volumeSize = UInt32(MemoryLayout<Float32>.size)

            var mainAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectSetPropertyData(defaultOutputDevice, &mainAddress, 0, nil, volumeSize, &volumeScalar)

            var ch1Address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 1
            )
            _ = AudioObjectSetPropertyData(defaultOutputDevice, &ch1Address, 0, nil, volumeSize, &volumeScalar)

            var ch2Address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 2
            )
            _ = AudioObjectSetPropertyData(defaultOutputDevice, &ch2Address, 0, nil, volumeSize, &volumeScalar)
        } else {
            // AppleScript fallback only if CoreAudio device lookup failed
            let volumePercent = Int(clamped * 100)
            Task {
                await AppleScriptRunner.run("set volume output volume \(volumePercent)")
            }
        }

        self.onVolumeChanged?(clamped, self.isMuted)
    }
}
