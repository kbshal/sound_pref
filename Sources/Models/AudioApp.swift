// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import AppKit
import CoreAudio
import Observation

/// Represents a running application that is producing audio.
///
/// Each `AudioApp` corresponds to a process object discovered via
/// `kAudioHardwarePropertyProcessObjectList`. It holds the user-visible
/// state (volume, mute, output device) that the UI binds to.
@Observable
final class AudioApp: Identifiable, @unchecked Sendable {

    // MARK: - Identity

    /// Unique identifier for this app — uses bundle ID for persistence across launches.
    var id: String { bundleID }

    /// The Core Audio process object ID (not the Unix PID).
    let processObjectID: AudioObjectID

    /// The application's bundle identifier (e.g. "com.apple.Music").
    let bundleID: String

    /// The Unix process ID.
    var pid: pid_t

    /// Human-readable application name.
    var name: String

    /// Application icon resolved from its bundle.
    var icon: NSImage?

    // MARK: - Audio Control State

    /// Volume level from 0.0 (silent) to 2.0 (200% boost).
    /// Values above 1.0 apply make-up gain.
    var volume: Float = 1.0

    /// Whether this app's audio is muted.
    var isMuted: Bool = false 

    /// The UID of the output device this app should route to.
    /// `nil` means "follow the system default output."
    var outputDeviceUID: String? = nil

    // MARK: - Live State

    /// Whether this process is currently producing audio output.
    var isRunningOutput: Bool = true

    /// Whether the user has pinned this app so it appears even when silent.
    var isFavorite: Bool = false

    /// Current peak audio level for the level meter (0.0–1.0).
    var peakLevel: Float = 0.0

    // MARK: - Engine State

    /// Whether a process tap is currently active for this app.
    var isTapped: Bool = false

    // MARK: - Init

    init(
        processObjectID: AudioObjectID,
        bundleID: String,
        pid: pid_t,
        name: String,
        icon: NSImage? = nil
    ) {
        self.processObjectID = processObjectID
        self.bundleID = bundleID
        self.pid = pid
        self.name = name
        self.icon = icon
    }
}

extension AudioApp: Equatable {
    static func == (lhs: AudioApp, rhs: AudioApp) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}

extension AudioApp: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
}
