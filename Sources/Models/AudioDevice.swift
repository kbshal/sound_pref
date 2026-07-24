// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import CoreAudio
import Foundation

/// Represents a physical or virtual audio device on the system.
///
/// Wraps a Core Audio `AudioObjectID` with user-friendly properties.
struct AudioDevice: Identifiable, Hashable, Sendable {

    /// The Core Audio object ID for this device.
    let id: AudioObjectID

    /// Persistent unique identifier string (survives reboots).
    let uid: String

    /// Human-readable device name (e.g. "MacBook Pro Speakers").
    let name: String

    /// Device manufacturer name.
    let manufacturer: String

    /// Core Audio transport type constant (e.g. built-in, USB, Bluetooth, HDMI).
    let transportType: UInt32

    /// Whether this device has input channels.
    let hasInput: Bool

    /// Whether this device has output channels.
    let hasOutput: Bool

    /// Current volume level (0.0–1.0). Only meaningful for devices with volume control.
    var volume: Float

    /// Whether the device is currently muted.
    var isMuted: Bool

    /// Number of output channels.
    let outputChannelCount: Int

    /// Number of input channels.
    let inputChannelCount: Int

    /// Sample rate in Hz.
    var sampleRate: Double

    // MARK: - Convenience

    /// SF Symbol name appropriate for this device's transport type.
    var systemImageName: String {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            return "macbook"
        case kAudioDeviceTransportTypeUSB:
            return "cable.connector"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "wave.3.right"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "tv"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeVirtual:
            return "waveform.circle"
        case kAudioDeviceTransportTypeAggregate:
            return "square.stack.3d.up"
        default:
            return "speaker.wave.2"
        }
    }

    /// Whether this device supports hardware volume control.
    var hasVolumeControl: Bool {
        // Devices like HDMI may not expose volume control through Core Audio.
        // We check this dynamically in AudioDeviceManager.
        true
    }
}

// MARK: - Transport Type Constants

/// Core Audio transport type constants for reference.
/// These match `kAudioDeviceTransportType*` from AudioHardwareBase.h.
extension AudioDevice {
    static let transportTypeBuiltIn = kAudioDeviceTransportTypeBuiltIn
    static let transportTypeUSB = kAudioDeviceTransportTypeUSB
    static let transportTypeBluetooth = kAudioDeviceTransportTypeBluetooth
    static let transportTypeHDMI = kAudioDeviceTransportTypeHDMI
    static let transportTypeDisplayPort = kAudioDeviceTransportTypeDisplayPort
    static let transportTypeVirtual = kAudioDeviceTransportTypeVirtual
}
