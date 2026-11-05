import Foundation
import CoreAudio
import Combine

@MainActor
public final class AudioActivityMonitor: ObservableObject {
    @Published public var isMicrophoneActive: Bool = false

    private var currentInputDeviceID: AudioDeviceID = 0
    private var isMonitoring: Bool = false

    public init() {
        startMonitoring()
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        updateDefaultDeviceAndRegisterListener()
        registerDefaultDeviceChangeListener()
    }

    public func stopMonitoring() {
        isMonitoring = false
        removeDeviceRunningListener()
    }

    private func updateDefaultDeviceAndRegisterListener() {
        removeDeviceRunningListener()

        var defaultDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &defaultDeviceID
        )

        guard status == noErr && defaultDeviceID != 0 else {
            isMicrophoneActive = false
            return
        }

        currentInputDeviceID = defaultDeviceID
        registerDeviceRunningListener(for: defaultDeviceID)
        checkDeviceRunning(deviceID: defaultDeviceID)
    }

    private func registerDefaultDeviceChangeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateDefaultDeviceAndRegisterListener()
            }
        }
    }

    private func registerDeviceRunningListener(for deviceID: AudioDeviceID) {
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &runningAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.checkDeviceRunning(deviceID: deviceID)
            }
        }
    }

    private func removeDeviceRunningListener() {
        guard currentInputDeviceID != 0 else { return }
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            currentInputDeviceID,
            &runningAddress,
            DispatchQueue.main,
            { _, _ in }
        )
        currentInputDeviceID = 0
    }

    private func checkDeviceRunning(deviceID: AudioDeviceID) {
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &runningAddress,
            0,
            nil,
            &size,
            &isRunning
        )

        if status == noErr {
            self.isMicrophoneActive = (isRunning == 1)
        } else {
            self.isMicrophoneActive = false
        }
    }
}
