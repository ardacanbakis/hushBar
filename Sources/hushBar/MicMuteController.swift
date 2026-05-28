import Foundation
import CoreAudio

/// Owns the system microphone's mute state.
///
/// Applies the input device's hardware mute flag (`kAudioDevicePropertyMute`)
/// across every input channel — many devices (including the built-in mic)
/// expose mute on the individual channels rather than the master element.
/// Devices with no settable mute fall back to forcing input volume to zero.
///
/// The published `isMuted` follows the user's intent so the control stays
/// responsive even on hardware that ignores the request.
final class MicMuteController: ObservableObject {

    @Published private(set) var isMuted: Bool = false

    /// Called on the main queue whenever `isMuted` changes.
    var onStateChange: ((Bool) -> Void)?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private let listenerQueue = DispatchQueue(label: "com.ardacanbakis.hushBar.coreaudio")

    /// Per-element volume saved before a fallback mute, restored on unmute.
    private var savedVolumes: [AudioObjectPropertyElement: Float32] = [:]

    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    private var deviceMuteListener: AudioObjectPropertyListenerBlock?

    /// Deadline (on listenerQueue) before which listener callbacks are suppressed.
    /// Set before each intentional write so competing apps can't flip the state back
    /// within the suppression window.
    private var suppressListenerUntil = Date.distantPast

    // MARK: - Lifecycle

    init() {
        deviceID = Self.defaultInputDevice()
        installDefaultDeviceListener()
        installDeviceMuteListener()
        isMuted = Self.readMuted(deviceID)
    }

    deinit {
        removeDeviceMuteListener()
        removeDefaultDeviceListener()
    }

    // MARK: - Public API

    func toggle() {
        hushLog("toggle isMuted=\(isMuted)")
        setMuted(!isMuted)
    }

    func setMuted(_ muted: Bool) {
        guard deviceID != AudioObjectID(kAudioObjectUnknown) else { return }
        hushLog("setMuted(\(muted))")
        apply(muted: muted, to: deviceID)
        // Reflect the real global state rather than assuming the write stuck.
        updateMuted(Self.readMuted(deviceID))
    }

    // MARK: - State

    private func updateMuted(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let changed = value != self.isMuted
            self.isMuted = value
            if changed {
                hushLog("state changed → isMuted=\(value)")
                self.onStateChange?(value)
            }
        }
    }

    private func apply(muted: Bool, to device: AudioObjectID) {
        // Pre-queue suppression on listenerQueue before the writes so the listener
        // callback triggered by our own write (and any competing write within 400ms)
        // is ignored. The async block is guaranteed to run before the post-write
        // listener block because both are serialised on the same queue.
        listenerQueue.async { [weak self] in
            self?.suppressListenerUntil = Date().addingTimeInterval(0.4)
        }
        logDeviceInfoOnce(device)
        let elements = Self.candidateElements(device)

        // Set the hardware mute flag; track which elements confirmed the write.
        var hwMuted = Set<AudioObjectPropertyElement>()
        for element in elements where Self.hasProperty(device, kAudioDevicePropertyMute, element: element) {
            let status = Self.setMute(device, element: element, muted: muted)
            let readback = Self.muteValue(device, element: element)
            hushLog("mute=\(muted ? 1 : 0) el=\(element) status=\(Int(status)) readback=\(readback ? 1 : 0)")
            if readback == muted { hwMuted.insert(element) }
        }

        // Volume fallback only for elements where hardware mute didn't confirm.
        // Writing vol=0 to elements that already have a working hardware mute
        // causes some built-in mic drivers to clear the mute flag (oscillation bug).
        for element in elements
        where !hwMuted.contains(element) && Self.hasProperty(device, kAudioDevicePropertyVolumeScalar, element: element) {
            if muted {
                if savedVolumes[element] == nil {
                    savedVolumes[element] = Self.volume(device, element: element) ?? 1
                }
                let status = Self.setVolume(device, element: element, value: 0)
                let readback = Self.volume(device, element: element) ?? -1
                hushLog("vol->0 el=\(element) status=\(Int(status)) readback=\(String(format: "%.3f", Double(readback)))")
            } else {
                let status = Self.setVolume(device, element: element, value: savedVolumes[element] ?? 1)
                hushLog("vol restore el=\(element) status=\(Int(status))")
            }
        }
        if !muted { savedVolumes.removeAll() }

        // Last resort: some drivers expose the *effective* control on the
        // global scope rather than the input scope we target above.
        applyGlobalScope(muted: muted, to: device)
    }

    private func applyGlobalScope(muted: Bool, to device: AudioObjectID) {
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        if AudioObjectHasProperty(device, &muteAddr) {
            var value: UInt32 = muted ? 1 : 0
            let status = AudioObjectSetPropertyData(
                device, &muteAddr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
            hushLog("global mute=\(muted ? 1 : 0) status=\(Int(status))")
        }

        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        if AudioObjectHasProperty(device, &volAddr) {
            var v: Float32 = muted ? 0 : 1
            let status = AudioObjectSetPropertyData(
                device, &volAddr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
            hushLog("global vol=\(String(format: "%.1f", Double(v))) status=\(Int(status))")
        }
    }

    private var didLogInfo = false
    private func logDeviceInfoOnce(_ device: AudioObjectID) {
        guard !didLogInfo else { return }
        didLogInfo = true
        hushLog("default input id=\(device) name=\(Self.deviceName(device)) channels=\(Self.inputChannelCount(device))")
        for element in Self.candidateElements(device) {
            let hasMute = Self.hasProperty(device, kAudioDevicePropertyMute, element: element)
            let hasVol = Self.hasProperty(device, kAudioDevicePropertyVolumeScalar, element: element)
            hushLog("el=\(element) hasMute=\(hasMute ? 1 : 0) hasVol=\(hasVol ? 1 : 0)")
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
        let newID = Self.defaultInputDevice()
        removeDeviceMuteListener()
        let deviceActuallyChanged = newID != deviceID
        deviceID = newID
        installDeviceMuteListener()
        hushLog("defaultDeviceChanged newID=\(newID) changed=\(deviceActuallyChanged ? 1 : 0)")
        // Spurious notifications fire when TCC grants mic permission without
        // switching devices — skip the re-apply to avoid an oscillation loop.
        guard deviceActuallyChanged else { return }
        if isMuted { setMuted(true) }
    }

    // MARK: - External mute change handling

    private func installDeviceMuteListener() {
        guard deviceID != AudioObjectID(kAudioObjectUnknown),
              !Self.muteElements(deviceID).isEmpty else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            let readback = Self.readMuted(self.deviceID)
            guard Date() > self.suppressListenerUntil else {
                hushLog("listener suppressed readback=\(readback ? 1 : 0)")
                return
            }
            hushLog("listener fired readback=\(readback ? 1 : 0)")
            self.updateMuted(readback)
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

    /// Master element plus channel elements. Always probes the first couple of
    /// channels even when the stream-configuration query reports none.
    private static func candidateElements(_ device: AudioObjectID) -> [AudioObjectPropertyElement] {
        var set: Set<AudioObjectPropertyElement> = [kAudioObjectPropertyElementMain, 1, 2]
        let channels = inputChannelCount(device)
        if channels > 0 {
            for i in 1...channels { set.insert(AudioObjectPropertyElement(i)) }
        }
        return set.sorted()
    }

    private static func inputChannelCount(_ device: AudioObjectID) -> UInt32 {
        guard device != AudioObjectID(kAudioObjectUnknown) else { return 0 }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr,
              size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(
            raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + $1.mNumberChannels }
    }

    private static func hasProperty(
        _ device: AudioObjectID, _ selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> Bool {
        guard device != AudioObjectID(kAudioObjectUnknown) else { return false }
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element)
        return AudioObjectHasProperty(device, &address)
    }

    private static func muteElements(_ device: AudioObjectID) -> [AudioObjectPropertyElement] {
        candidateElements(device).filter { hasProperty(device, kAudioDevicePropertyMute, element: $0) }
    }

    private static func volumeElements(_ device: AudioObjectID) -> [AudioObjectPropertyElement] {
        candidateElements(device).filter { hasProperty(device, kAudioDevicePropertyVolumeScalar, element: $0) }
    }

    @discardableResult
    private static func setMute(_ device: AudioObjectID, element: AudioObjectPropertyElement, muted: Bool) -> OSStatus {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element)
        var value: UInt32 = muted ? 1 : 0
        return AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    private static func muteValue(_ device: AudioObjectID, element: AudioObjectPropertyElement) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return value != 0
    }

    private static func volume(_ device: AudioObjectID, element: AudioObjectPropertyElement) -> Float32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    @discardableResult
    private static func setVolume(_ device: AudioObjectID, element: AudioObjectPropertyElement, value: Float32) -> OSStatus {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element)
        var v = value
        return AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
    }

    private static func deviceName(_ device: AudioObjectID) -> String {
        guard device != AudioObjectID(kAudioObjectUnknown) else { return "unknown" }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr,
              let cf = name?.takeRetainedValue() else { return "unknown" }
        return cf as String
    }

    private static func readMuted(_ device: AudioObjectID) -> Bool {
        let muteEls = muteElements(device)
        if !muteEls.isEmpty {
            return muteEls.allSatisfy { muteValue(device, element: $0) }
        }
        let volumeEls = volumeElements(device)
        if !volumeEls.isEmpty {
            return volumeEls.allSatisfy { (volume(device, element: $0) ?? 1) <= 0.0001 }
        }
        return false
    }
}
