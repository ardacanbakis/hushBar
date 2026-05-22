import Foundation
import CoreAudio

/// Owns the system microphone's mute state.
///
/// Primary path: toggle the input device's hardware mute flag
/// (`kAudioDevicePropertyMute`), which applies driver-level to every app.
/// Fallback for devices without a settable mute flag: drive the input volume
/// to zero and restore the previous level on unmute.
///
/// Reading/writing the mute flag does not touch audio samples, so this does not
/// trigger the macOS microphone (TCC) permission prompt.
final class MicMuteController: ObservableObject {

    @Published private(set) var isMuted: Bool = false

    /// Called on the main queue whenever `isMuted` changes for any reason
    /// (including external changes made elsewhere in the system).
    var onStateChange: ((Bool) -> Void)?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private let listenerQueue = DispatchQueue(label: "com.ardacanbakis.mcDrop.coreaudio")

    /// Volume saved before a fallback mute, so it can be restored on unmute.
    private var savedVolume: Float32?

    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    private var deviceMuteListener: AudioObjectPropertyListenerBlock?

    // MARK: - Lifecycle

    init() {
        deviceID = Self.defaultInputDevice()
        installDefaultDeviceListener()
        installDeviceMuteListener()
        refreshStateFromDevice()
    }

    deinit {
        removeDeviceMuteListener()
        removeDefaultDeviceListener()
    }

    // MARK: - Public API

    func toggle() {
        setMuted(!isMuted)
    }

    func setMuted(_ muted: Bool) {
        guard deviceID != AudioObjectID(kAudioObjectUnknown) else { return }

        if Self.deviceSupportsMute(deviceID) {
            Self.setDeviceMute(deviceID, muted: muted)
        } else {
            applyVolumeFallback(muted: muted)
        }

        // Re-read so published state reflects what the hardware actually did.
        refreshStateFromDevice()
    }

    // MARK: - State sync

    private func updateMuted(_ value: Bool) {
        let changed = value != isMuted
        isMuted = value
        if changed { onStateChange?(value) }
    }

    private func refreshStateFromDevice() {
        let muted: Bool
        if Self.deviceSupportsMute(deviceID) {
            muted = Self.deviceMuteValue(deviceID)
        } else {
            muted = (Self.inputVolume(deviceID) ?? 1) <= 0.0001
        }
        DispatchQueue.main.async { [weak self] in
            self?.updateMuted(muted)
        }
    }

    // MARK: - Default device change handling

    private func installDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.handleDefaultDeviceChanged()
        }
        defaultDeviceListener = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, listenerQueue, block)
    }

    private func removeDefaultDeviceListener() {
        guard let block = defaultDeviceListener else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, listenerQueue, block)
        defaultDeviceListener = nil
    }

    private func handleDefaultDeviceChanged() {
        let wantedMuted = isMuted
        removeDeviceMuteListener()
        deviceID = Self.defaultInputDevice()
        installDeviceMuteListener()
        // Carry the user's intended state onto the newly-selected device.
        setMuted(wantedMuted)
    }

    // MARK: - Device mute change handling (external changes)

    private func installDeviceMuteListener() {
        guard deviceID != AudioObjectID(kAudioObjectUnknown),
              Self.deviceSupportsMute(deviceID) else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshStateFromDevice()
        }
        deviceMuteListener = block
        AudioObjectAddPropertyListenerBlock(deviceID, &address, listenerQueue, block)
    }

    private func removeDeviceMuteListener() {
        guard let block = deviceMuteListener,
              deviceID != AudioObjectID(kAudioObjectUnknown) else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectRemovePropertyListenerBlock(deviceID, &address, listenerQueue, block)
        deviceMuteListener = nil
    }

    // MARK: - Volume fallback

    private func applyVolumeFallback(muted: Bool) {
        if muted {
            if savedVolume == nil {
                savedVolume = Self.inputVolume(deviceID) ?? 1.0
            }
            Self.setInputVolume(deviceID, value: 0.0)
        } else {
            let restore = savedVolume ?? 1.0
            Self.setInputVolume(deviceID, value: restore)
            savedVolume = nil
        }
    }

    // MARK: - CoreAudio helpers

    private static func defaultInputDevice() -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    private static func deviceSupportsMute(_ device: AudioObjectID) -> Bool {
        guard device != AudioObjectID(kAudioObjectUnknown) else { return false }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(device, &address, &settable)
        return status == noErr && settable.boolValue
    }

    private static func deviceMuteValue(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted)
        return muted != 0
    }

    private static func setDeviceMute(_ device: AudioObjectID, muted: Bool) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
    }

    /// Reads input volume from the master element, falling back to channel 1.
    private static func inputVolume(_ device: AudioObjectID) -> Float32? {
        for element in [kAudioObjectPropertyElementMain, 1] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: AudioObjectPropertyElement(element))
            guard AudioObjectHasProperty(device, &address) else { continue }
            var volume: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr {
                return volume
            }
        }
        return nil
    }

    /// Writes input volume to whichever elements are settable (master and/or channels).
    private static func setInputVolume(_ device: AudioObjectID, value: Float32) {
        var didSet = false
        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: AudioObjectPropertyElement(element))
            guard AudioObjectHasProperty(device, &address) else { continue }
            var settable: DarwinBoolean = false
            guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
                  settable.boolValue else { continue }
            var v = value
            let size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectSetPropertyData(device, &address, 0, nil, size, &v) == noErr {
                didSet = true
            }
        }
        _ = didSet
    }
}
