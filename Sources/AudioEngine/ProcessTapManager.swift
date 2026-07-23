// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import AVFAudio
import AudioToolbox
import CoreAudio
import Foundation

/// Manages a single process tap: capturing audio from one app,
/// processing it (gain/mute), and routing it to an output device.
///
/// Each `ProcessTapManager` handles the lifecycle of:
/// 1. A `CATapDescription` + `AudioHardwareCreateProcessTap` for capture
/// 2. An aggregate device that exposes the tap as an input stream
/// 3. An `AVAudioEngine` graph: tap input → gain → output device
///
/// The tap's mute behavior controls whether the original audio is suppressed
/// on the source device (redirection mode) or left playing (monitor mode).
@available(macOS 14.2, *)
final class ProcessTapManager: @unchecked Sendable {

    // MARK: - Properties

    /// The bundle ID of the app being tapped.
    let bundleID: String

    /// The Core Audio process object ID being tapped.
    let processObjectID: AudioObjectID

    /// The created tap's AudioObjectID.
    private(set) var tapID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)

    /// The aggregate device's AudioObjectID.
    private(set) var aggregateDeviceID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)

    /// The AVAudioEngine processing graph.
    private var engine: AVAudioEngine?

    /// Gain node for volume control.
    private var gainNode: AVAudioMixerNode?

    /// Whether the tap is currently active.
    private(set) var isActive: Bool = false

    /// Current gain value (0.0–2.0).
    private var currentGain: Float = 1.0

    /// Whether audio is muted.
    private var isMuted: Bool = false

    /// Callback for peak level updates (for the UI meter).
    var onPeakLevelUpdate: ((Float) -> Void)?

    /// The target output device UID (nil = system default).
    private var targetOutputDeviceUID: String?

    /// Whether we should mute the source (redirection mode) or not (monitor mode).
    private let muteSource: Bool

    // MARK: - Initialization

    /// Create a new ProcessTapManager for a specific app.
    ///
    /// - Parameters:
    ///   - bundleID: The app's bundle identifier.
    ///   - processObjectID: The Core Audio process object ID.
    ///   - muteSource: If true, the original audio is muted on the source device
    ///     (enabling true redirection). If false, audio is monitored but still plays normally.
    ///   - targetOutputDeviceUID: UID of the output device to route to, or nil for system default.
    init(
        bundleID: String,
        processObjectID: AudioObjectID,
        muteSource: Bool = true,
        targetOutputDeviceUID: String? = nil
    ) {
        self.bundleID = bundleID
        self.processObjectID = processObjectID
        self.muteSource = muteSource
        self.targetOutputDeviceUID = targetOutputDeviceUID
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Start capturing audio from the target process.
    ///
    /// This creates the tap, builds the aggregate device, sets up the
    /// AVAudioEngine graph, and starts playback.
    func start() throws {
        guard !isActive else { return }

        // Step 1: Create the process tap
        try createProcessTap()

        // Step 2: Create aggregate device with the tap
        try createAggregateDevice()

        // Step 3: Set up AVAudioEngine for processing + output
        try setupAudioEngine()

        // Step 4: Start the engine
        try engine?.start()

        isActive = true
    }

    /// Stop capturing and clean up all resources.
    func stop() {
        guard isActive else { return }

        engine?.stop()
        engine = nil
        gainNode = nil

        // Destroy aggregate device
        if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        }

        // Destroy tap
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }

        isActive = false
    }

    // MARK: - Audio Control

    /// Set the gain/volume for this tap (0.0–2.0).
    func setGain(_ gain: Float) {
        currentGain = max(0.0, min(2.0, gain))
        gainNode?.outputVolume = isMuted ? 0.0 : currentGain
    }

    /// Set the mute state for this tap.
    func setMuted(_ muted: Bool) {
        isMuted = muted
        gainNode?.outputVolume = muted ? 0.0 : currentGain
    }

    /// Change the output device for this tap.
    /// Requires restarting the engine with the new device.
    func setOutputDevice(uid: String?) throws {
        let wasActive = isActive
        if wasActive { stop() }
        targetOutputDeviceUID = uid
        if wasActive { try start() }
    }

    // MARK: - Private: Tap Creation

    /// Create a Core Audio process tap targeting our process.
    private func createProcessTap() throws {
        let tapDescription = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
        tapDescription.name = "com.opensoundsource.tap.\(bundleID)"
        tapDescription.isPrivate = true

        // Set mute behavior
        if muteSource {
            tapDescription.muteBehavior = .mutedWhenTapped
        } else {
            tapDescription.muteBehavior = .unmuted
        }

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(tapDescription, &newTapID)
        guard status == noErr else {
            throw CoreAudioError.createTapFailed(status)
        }

        tapID = newTapID
    }

    /// Create an aggregate device that includes our tap as an input source.
    private func createAggregateDevice() throws {
        // Get the tap's UID
        let tapUID = try getTapUID(tapID: tapID)

        let aggregateUID = "com.opensoundsource.aggregate.\(bundleID).\(UUID().uuidString.prefix(8))"

        // Build the aggregate device description
        let tapEntry: [String: Any] = [
            kAggregateDeviceTapUIDKey as String: tapUID
        ]

        var description: [String: Any] = [
            kAggregateDeviceUIDKey as String: aggregateUID,
            kAggregateDeviceNameKey as String: "OSS Tap: \(bundleID)",
            kAggregateDeviceIsPrivateKey as String: true,
            kAggregateDeviceIsStackedKey as String: false,
            kAggregateDeviceTapListKey as String: [tapEntry],
        ]

        // If we have a specific output device, add it as a sub-device
        if let outputUID = targetOutputDeviceUID {
            description[kAggregateDeviceMainSubDeviceKey as String] = outputUID
        }

        var newAggregateID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(
            description as CFDictionary,
            &newAggregateID
        )
        guard status == noErr else {
            // Clean up the tap if aggregate creation fails
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
            throw CoreAudioError.createAggregateFailed(status)
        }

        aggregateDeviceID = newAggregateID
    }

    // MARK: - Private: Audio Engine Setup

    /// Set up the AVAudioEngine graph for processing tapped audio.
    private func setupAudioEngine() throws {
        let newEngine = AVAudioEngine()

        // Configure the engine to use our aggregate device as input
        // The aggregate device's input streams come from the tap
        do {
            try newEngine.inputNode.setVoiceProcessingEnabled(false)
        } catch {
            // Voice processing may not be relevant, continue
        }

        // Set the aggregate device as the input device for the engine
        setEngineDevice(newEngine.inputNode, deviceID: aggregateDeviceID, isInput: true)

        // If we have a specific output device, set it
        if let outputUID = targetOutputDeviceUID,
           let outputDeviceID = resolveDeviceID(forUID: outputUID) {
            setEngineDevice(newEngine.outputNode, deviceID: outputDeviceID, isInput: false)
        }

        // Create gain/mixer node
        let mixer = AVAudioMixerNode()
        newEngine.attach(mixer)

        // Get the input format from the aggregate device
        let inputFormat = newEngine.inputNode.outputFormat(forBus: 0)

        // Connect: input → mixer → output
        // Use the input format to avoid sample rate conversion issues
        let processingFormat = AVAudioFormat(
            standardFormatWithSampleRate: inputFormat.sampleRate,
            channels: min(inputFormat.channelCount, 2) // Stereo max
        ) ?? inputFormat

        newEngine.connect(newEngine.inputNode, to: mixer, format: processingFormat)
        newEngine.connect(mixer, to: newEngine.mainMixerNode, format: processingFormat)

        // Apply current gain
        mixer.outputVolume = isMuted ? 0.0 : currentGain

        // Install a tap on the mixer for level metering
        if let onPeakLevelUpdate = onPeakLevelUpdate {
            let meterFormat = mixer.outputFormat(forBus: 0)
            if meterFormat.sampleRate > 0 && meterFormat.channelCount > 0 {
                mixer.installTap(onBus: 0, bufferSize: 1024, format: meterFormat) { buffer, _ in
                    let channelData = buffer.floatChannelData?[0]
                    let frameLength = Int(buffer.frameLength)
                    guard let data = channelData, frameLength > 0 else {
                        onPeakLevelUpdate(0.0)
                        return
                    }

                    var peak: Float = 0.0
                    for i in 0..<frameLength {
                        let sample = abs(data[i])
                        if sample > peak { peak = sample }
                    }

                    // Send peak level back (clamp to 0–1)
                    onPeakLevelUpdate(min(peak, 1.0))
                }
            }
        }

        engine = newEngine
        gainNode = mixer
    }

    /// Set the audio device for an AVAudioEngine node using Core Audio.
    private func setEngineDevice(_ node: AVAudioNode, deviceID: AudioObjectID, isInput: Bool) {
        // AVAudioEngine nodes wrap an AudioUnit internally.
        // We need to set the kAudioOutputUnitProperty_CurrentDevice property.
        guard let audioUnit = node.audioUnit else { return }

        var devID = deviceID
        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            isInput ? kAudioUnitScope_Global : kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioObjectID>.size)
        )
    }

    /// Resolve a device UID to an AudioObjectID.
    private func resolveDeviceID(forUID uid: String) -> AudioObjectID? {
        var address = makePropertyAddress(
            selector: kAudioHardwarePropertyDeviceForUID
        )
        
        var cfuid: CFString = uid as CFString
        var result: AudioObjectID? = nil
        
        withUnsafePointer(to: &cfuid) { uidPtr in
            var translation = AudioValueTranslation(
                mInputData: UnsafeMutableRawPointer(mutating: uidPtr),
                mInputDataSize: UInt32(MemoryLayout<CFString>.size),
                mOutputData: UnsafeMutableRawPointer.allocate(
                    byteCount: MemoryLayout<AudioObjectID>.size,
                    alignment: MemoryLayout<AudioObjectID>.alignment
                ),
                mOutputDataSize: UInt32(MemoryLayout<AudioObjectID>.size)
            )
            defer { translation.mOutputData.deallocate() }
            
            var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
            let status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &size,
                &translation
            )
            
            if status == noErr {
                result = translation.mOutputData.load(as: AudioObjectID.self)
            }
        }
        
        return result
    }
}
