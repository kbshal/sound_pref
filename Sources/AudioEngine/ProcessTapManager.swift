// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import AudioToolbox
import CoreAudio
import Foundation

/// Manages a single process tap: capturing audio from one app,
/// processing it (gain/mute), and routing it to an output device.
///
/// Each `ProcessTapManager` handles the lifecycle of:
/// 1. A `CATapDescription` + `AudioHardwareCreateProcessTap` for capture
/// 2. An aggregate device containing the tap (input) and the target
///    physical device (output), with drift compensation on the tap
/// 3. An IOProc on the aggregate that copies tap input → device output
///    with gain applied
///
/// Running an IOProc directly on the aggregate keeps capture and playback
/// on one device/clock, which is required for reliable routing — especially
/// to Bluetooth devices that run on their own clock domain.
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

    /// The IOProc that moves audio from the tap to the output device.
    private var ioProcID: AudioDeviceIOProcID?

    /// Whether the tap is currently active.
    private(set) var isActive: Bool = false

    /// Current gain value (0.0–2.0). Read from the realtime IO thread.
    private var currentGain: Float = 1.0

    /// Whether audio is muted. Read from the realtime IO thread.
    private var isMuted: Bool = false

    /// Callback for peak level updates (for the UI meter).
    /// Called from the realtime IO thread.
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
    /// This creates the tap, builds the aggregate device, and starts
    /// the IOProc that routes audio to the output device.
    func start() throws {
        guard !isActive else { return }

        // Step 1: Create the process tap
        try createProcessTap()

        // Step 2: Create aggregate device with the tap + output device
        try createAggregateDevice()

        // Step 3: Start the IOProc that copies tap audio to the output
        try startIOProc()

        isActive = true
    }

    /// Stop capturing and clean up all resources.
    func stop() {
        guard isActive else { return }

        // Stop and destroy the IOProc
        if let procID = ioProcID, aggregateDeviceID != AudioObjectID(kAudioObjectUnknown) {
            AudioDeviceStop(aggregateDeviceID, procID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
        }
        ioProcID = nil

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
    }

    /// Set the mute state for this tap.
    func setMuted(_ muted: Bool) {
        isMuted = muted
    }

    /// Change the output device for this tap.
    /// Requires rebuilding the aggregate with the new device.
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
        tapDescription.name = "com.soundpref.tap.\(bundleID)"
        tapDescription.isPrivate = true

        // Always mute the source process so that we don't get double audio when tapped!
        tapDescription.muteBehavior = .mutedWhenTapped

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(tapDescription, &newTapID)
        guard status == noErr else {
            throw CoreAudioError.createTapFailed(status)
        }

        tapID = newTapID
    }

    /// Create an aggregate device with the target output device as its
    /// sub-device and the tap in its tap list. The tap's audio then arrives
    /// as the aggregate's input, and the aggregate's output goes to the
    /// physical device.
    private func createAggregateDevice() throws {
        // Get the tap's UID
        let tapUID = try getTapUID(tapID: tapID)

        // The aggregate always needs a real output device. Use the user's
        // chosen device, or fall back to the current system default (for
        // volume/mute-only taps with no redirection).
        let outputUID = try targetOutputDeviceUID ?? defaultOutputDeviceUID()

        let aggregateUID = "com.soundpref.aggregate.\(bundleID).\(UUID().uuidString.prefix(8))"

        let tapEntry: [String: Any] = [
            kAggregateDeviceTapUIDKey as String: tapUID,
            "drift": 1 // Enable drift compensation (resampling) to match the master clock
        ]

        let description: [String: Any] = [
            kAggregateDeviceUIDKey as String: aggregateUID,
            kAggregateDeviceNameKey as String: "OSS Tap: \(bundleID)",
            kAggregateDeviceIsPrivateKey as String: true,
            kAggregateDeviceIsStackedKey as String: false,
            kAggregateDeviceTapListKey as String: [tapEntry],
            "subdevices": [
                ["uid": outputUID]
            ],
            kAggregateDeviceMainSubDeviceKey as String: outputUID,
        ]

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

    // MARK: - Private: IO

    /// Install and start an IOProc on the aggregate device.
    ///
    /// The IOProc receives the tap's audio as input buffers and writes
    /// them (scaled by gain) into the output buffers, which the aggregate
    /// delivers to the physical output device.
    private func startIOProc() throws {
        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateDeviceID, nil) {
            [weak self] _, inInputData, _, outOutputData, _ in

            // If we're gone, output silence.
            let gain: Float
            let levelCallback: ((Float) -> Void)?
            if let self {
                gain = self.isMuted ? 0.0 : self.currentGain
                levelCallback = self.onPeakLevelUpdate
            } else {
                gain = 0.0
                levelCallback = nil
            }

            let input = UnsafeMutableAudioBufferListPointer(
                UnsafeMutablePointer(mutating: inInputData)
            )
            let output = UnsafeMutableAudioBufferListPointer(outOutputData)

            var peak: Float = 0.0

            for (index, outBuffer) in output.enumerated() {
                guard let outData = outBuffer.mData else { continue }
                let outSamples = outData.assumingMemoryBound(to: Float.self)
                let outCount = Int(outBuffer.mDataByteSize) / MemoryLayout<Float>.size

                if index < input.count, let inData = input[index].mData {
                    let inSamples = inData.assumingMemoryBound(to: Float.self)
                    let inCount = Int(input[index].mDataByteSize) / MemoryLayout<Float>.size
                    let count = min(outCount, inCount)

                    for i in 0..<count {
                        let sample = inSamples[i] * gain
                        outSamples[i] = sample
                        let magnitude = abs(sample)
                        if magnitude > peak { peak = magnitude }
                    }
                    // Zero any remaining output samples
                    for i in count..<outCount {
                        outSamples[i] = 0.0
                    }
                } else {
                    // No matching input buffer: output silence
                    for i in 0..<outCount {
                        outSamples[i] = 0.0
                    }
                }
            }

            levelCallback?(min(peak, 1.0))
        }

        guard status == noErr, let procID else {
            throw CoreAudioError.createAggregateFailed(status)
        }

        let startStatus = AudioDeviceStart(aggregateDeviceID, procID)
        guard startStatus == noErr else {
            AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
            throw CoreAudioError.createAggregateFailed(startStatus)
        }

        ioProcID = procID
    }

    // MARK: - Private: Device Lookup

    /// Get the UID of the current system default output device.
    private func defaultOutputDeviceUID() throws -> String {
        let deviceID: AudioObjectID = try getAudioObjectProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: makePropertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice)
        )
        return try getAudioObjectPropertyString(
            objectID: deviceID,
            address: makePropertyAddress(selector: kAudioDevicePropertyDeviceUID)
        )
    }
}
