// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import CoreAudio
import AudioToolbox
import Foundation

/// Enumerates and manages system audio devices (input and output).
///
/// Monitors device hot-plug/removal and provides methods to get/set
/// volume, mute, and default device selection.
@MainActor
@Observable
final class AudioDeviceManager {

    /// All currently available output devices.
    private(set) var outputDevices: [AudioDevice] = []

    /// All currently available input devices.
    private(set) var inputDevices: [AudioDevice] = []

    /// The current system default output device.
    private(set) var defaultOutputDevice: AudioDevice?

    /// The current system default input device.
    private(set) var defaultInputDevice: AudioDevice?

    /// Property listener tokens (retained to keep listeners alive).
    private var listenerTokens: [PropertyListenerToken] = []

    // MARK: - Initialization

    init() {
        refreshDevices()
        installListeners()
    }

    deinit {
        let tokens = listenerTokens
        Task { @MainActor in
            tokens.forEach { $0.remove() }
        }
    }

    // MARK: - Device Enumeration

    /// Refresh the list of all audio devices from Core Audio.
    func refreshDevices() {
        let address = makePropertyAddress(
            selector: kAudioHardwarePropertyDevices
        )

        guard let deviceIDs = try? getAudioObjectPropertyArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: address
        ) as [AudioObjectID] else {
            outputDevices = []
            inputDevices = []
            return
        }

        var outputs: [AudioDevice] = []
        var inputs: [AudioDevice] = []

        for deviceID in deviceIDs {
            guard let device = buildAudioDevice(id: deviceID) else { continue }

            // Skip aggregate devices we created ourselves
            if device.uid.hasPrefix("com.opensoundsource.") { continue }

            if device.hasOutput {
                outputs.append(device)
            }
            if device.hasInput {
                inputs.append(device)
            }
        }

        outputDevices = outputs
        inputDevices = inputs

        // Update default devices
        refreshDefaultDevices()
    }

    /// Refresh which device is the system default.
    func refreshDefaultDevices() {
        // Default output
        let outputAddr = makePropertyAddress(
            selector: kAudioHardwarePropertyDefaultOutputDevice
        )
        if let defaultOutputID = try? getAudioObjectProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: outputAddr
        ) as AudioObjectID {
            defaultOutputDevice = outputDevices.first { $0.id == defaultOutputID }
        }

        // Default input
        let inputAddr = makePropertyAddress(
            selector: kAudioHardwarePropertyDefaultInputDevice
        )
        if let defaultInputID = try? getAudioObjectProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: inputAddr
        ) as AudioObjectID {
            defaultInputDevice = inputDevices.first { $0.id == defaultInputID }
        }
    }

    // MARK: - Device Control

    /// Set the system default output device.
    func setDefaultOutputDevice(_ device: AudioDevice) throws {
        let address = makePropertyAddress(
            selector: kAudioHardwarePropertyDefaultOutputDevice
        )
        try setAudioObjectProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: address,
            value: device.id
        )
    }

    /// Set the system default input device.
    func setDefaultInputDevice(_ device: AudioDevice) throws {
        let address = makePropertyAddress(
            selector: kAudioHardwarePropertyDefaultInputDevice
        )
        try setAudioObjectProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: address,
            value: device.id
        )
    }

    /// Get the volume of a specific device (output scope, channel 0 = master).
    func getDeviceVolume(deviceID: AudioObjectID) -> Float? {
        let address = makePropertyAddress(
            selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            scope: kAudioDevicePropertyScopeOutput
        )
        return try? getAudioObjectProperty(objectID: deviceID, address: address)
    }

    /// Set the volume of a specific device.
    func setDeviceVolume(deviceID: AudioObjectID, volume: Float) throws {
        let address = makePropertyAddress(
            selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            scope: kAudioDevicePropertyScopeOutput
        )
        try setAudioObjectProperty(objectID: deviceID, address: address, value: volume)
    }

    /// Get the mute state of a specific device.
    func getDeviceMute(deviceID: AudioObjectID) -> Bool {
        let address = makePropertyAddress(
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput
        )
        let value: UInt32 = (try? getAudioObjectProperty(objectID: deviceID, address: address)) ?? 0
        return value != 0
    }

    /// Set the mute state of a specific device.
    func setDeviceMute(deviceID: AudioObjectID, muted: Bool) throws {
        let address = makePropertyAddress(
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput
        )
        try setAudioObjectProperty(objectID: deviceID, address: address, value: UInt32(muted ? 1 : 0))
    }

    /// Find a device by its UID string.
    func device(forUID uid: String) -> AudioDevice? {
        outputDevices.first { $0.uid == uid } ?? inputDevices.first { $0.uid == uid }
    }

    /// Get the AudioObjectID for a device UID.
    func deviceID(forUID uid: String) -> AudioObjectID? {
        device(forUID: uid)?.id
    }

    // MARK: - Private Helpers

    /// Build an AudioDevice model from a Core Audio device ID.
    private func buildAudioDevice(id: AudioObjectID) -> AudioDevice? {
        // Device UID
        guard let uid = try? getAudioObjectPropertyString(
            objectID: id,
            address: makePropertyAddress(selector: kAudioDevicePropertyDeviceUID)
        ) else { return nil }

        // Device name
        let name = (try? getAudioObjectPropertyString(
            objectID: id,
            address: makePropertyAddress(selector: kAudioObjectPropertyName)
        )) ?? "Unknown Device"

        // Manufacturer
        let manufacturer = (try? getAudioObjectPropertyString(
            objectID: id,
            address: makePropertyAddress(selector: kAudioObjectPropertyManufacturer)
        )) ?? ""

        // Transport type
        let transportType: UInt32 = (try? getAudioObjectProperty(
            objectID: id,
            address: makePropertyAddress(selector: kAudioDevicePropertyTransportType)
        )) ?? 0

        // Channel counts (to determine input/output capability)
        let outputChannels = channelCount(deviceID: id, scope: kAudioDevicePropertyScopeOutput)
        let inputChannels = channelCount(deviceID: id, scope: kAudioDevicePropertyScopeInput)

        // Volume & mute
        let volume = getDeviceVolume(deviceID: id) ?? 1.0
        let isMuted = getDeviceMute(deviceID: id)

        // Sample rate
        let sampleRate: Float64 = (try? getAudioObjectProperty(
            objectID: id,
            address: makePropertyAddress(selector: kAudioDevicePropertyNominalSampleRate)
        )) ?? 44100.0

        return AudioDevice(
            id: id,
            uid: uid,
            name: name,
            manufacturer: manufacturer,
            transportType: transportType,
            hasInput: inputChannels > 0,
            hasOutput: outputChannels > 0,
            volume: volume,
            isMuted: isMuted,
            outputChannelCount: outputChannels,
            inputChannelCount: inputChannels,
            sampleRate: sampleRate
        )
    }

    /// Count the number of channels for a device in a given scope.
    private func channelCount(deviceID: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        let address = makePropertyAddress(
            selector: kAudioDevicePropertyStreamConfiguration,
            scope: scope
        )

        var size: UInt32 = 0
        var addr = address
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size) == noErr,
              size > 0 else {
            return 0
        }

        let bufferList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferList.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, bufferList) == noErr else {
            return 0
        }

        let abl = bufferList.assumingMemoryBound(to: AudioBufferList.self).pointee
        let bufferCount = Int(abl.mNumberBuffers)
        guard bufferCount > 0 else { return 0 }

        // Sum up channels across all buffers
        var totalChannels = 0
        let buffersPtr = UnsafeMutableAudioBufferListPointer(bufferList.assumingMemoryBound(to: AudioBufferList.self))
        for buffer in buffersPtr {
            totalChannels += Int(buffer.mNumberChannels)
        }

        return totalChannels
    }

    // MARK: - Listeners

    /// Install listeners for device changes (hot-plug, default device changes).
    private func installListeners() {
        let queue = DispatchQueue.main

        // Device list changed (hot-plug/removal)
        if let token = try? addPropertyListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: makePropertyAddress(selector: kAudioHardwarePropertyDevices),
            queue: queue,
            block: { [weak self] _, _ in
                Task { @MainActor in
                    self?.refreshDevices()
                }
            }
        ) {
            listenerTokens.append(token)
        }

        // Default output device changed
        if let token = try? addPropertyListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: makePropertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice),
            queue: queue,
            block: { [weak self] _, _ in
                Task { @MainActor in
                    self?.refreshDefaultDevices()
                }
            }
        ) {
            listenerTokens.append(token)
        }

        // Default input device changed
        if let token = try? addPropertyListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: makePropertyAddress(selector: kAudioHardwarePropertyDefaultInputDevice),
            queue: queue,
            block: { [weak self] _, _ in
                Task { @MainActor in
                    self?.refreshDefaultDevices()
                }
            }
        ) {
            listenerTokens.append(token)
        }
    }
}
