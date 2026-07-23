// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import CoreAudio
import AudioToolbox
import AppKit
import Foundation
import Observation

/// Discovers running processes that are producing audio output.
///
/// Uses `kAudioHardwarePropertyProcessObjectList` to enumerate audio processes
/// and monitors for changes as apps start/stop producing audio.
@MainActor
@Observable
final class AudioProcessDiscovery {

    /// Currently active audio-producing apps.
    private(set) var activeApps: [AudioApp] = []

    /// All known apps (active + favorites that persisted).
    private(set) var allVisibleApps: [AudioApp] = []

    /// Property listener tokens.
    private var listenerTokens: [PropertyListenerToken] = []

    /// Bundle IDs to exclude from the list (our own app, system daemons, etc.).
    private let excludedBundleIDs: Set<String> = [
        "com.opensoundsource.app",
        "com.apple.audio.SandboxHelper",
        "com.apple.WebKit.GPU",
    ]

    // MARK: - Initialization

    init() {
        refreshProcesses()
        installListeners()
    }
    // MARK: - Process Enumeration

    /// Refresh the list of audio-producing processes from Core Audio.
    func refreshProcesses() {
        let address = makePropertyAddress(
            selector: kAudioHardwarePropertyProcessObjectList
        )

        guard let processObjectIDs = try? getAudioObjectPropertyArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: address
        ) as [AudioObjectID] else {
            activeApps = []
            updateVisibleApps()
            return
        }

        var discovered: [AudioApp] = []

        for processObjectID in processObjectIDs {
            guard let app = buildAudioApp(processObjectID: processObjectID) else { continue }

            // Skip excluded apps
            if excludedBundleIDs.contains(app.bundleID) { continue }

            // Only include apps currently running output
            if app.isRunningOutput {
                discovered.append(app)
            }
        }

        // Merge with existing apps to preserve user state (volume, mute, etc.)
        mergeDiscovered(discovered)
        updateVisibleApps()
    }

    // MARK: - Private Helpers

    /// Build an AudioApp model from a Core Audio process object ID.
    private func buildAudioApp(processObjectID: AudioObjectID) -> AudioApp? {
        // Get bundle ID
        guard let bundleID = try? getAudioObjectPropertyString(
            objectID: processObjectID,
            address: makePropertyAddress(selector: kAudioProcessPropertyBundleID)
        ) else { return nil }

        // Get PID
        let pid: pid_t = (try? getAudioObjectProperty(
            objectID: processObjectID,
            address: makePropertyAddress(selector: kAudioProcessPropertyPID)
        )) ?? 0

        // Check if producing output
        let isRunningOutput: UInt32 = (try? getAudioObjectProperty(
            objectID: processObjectID,
            address: makePropertyAddress(selector: kAudioProcessPropertyIsRunningOutput)
        )) ?? 0

        // Resolve app metadata
        let (name, icon) = BundleIDResolver.resolve(bundleID: bundleID, pid: pid)

        let app = AudioApp(
            processObjectID: processObjectID,
            bundleID: bundleID,
            pid: pid,
            name: name,
            icon: icon
        )
        app.isRunningOutput = isRunningOutput != 0

        // Load persisted settings
        let settings = SettingsStore.shared.settings(for: bundleID)
        app.volume = settings.volume
        app.isMuted = settings.isMuted
        app.outputDeviceUID = settings.outputDeviceUID
        app.isFavorite = settings.isFavorite

        return app
    }

    /// Merge newly discovered apps with existing state.
    /// Preserves user-set values (volume, mute, output device) for apps
    /// that were already known.
    private func mergeDiscovered(_ discovered: [AudioApp]) {
        var merged: [AudioApp] = []
        let existingByID = Dictionary(uniqueKeysWithValues: activeApps.map { ($0.bundleID, $0) })

        for newApp in discovered {
            if let existing = existingByID[newApp.bundleID] {
                // Update the process object ID and PID (may have changed)
                existing.pid = newApp.pid
                existing.isRunningOutput = newApp.isRunningOutput
                // Keep the existing app with its user-modified state
                merged.append(existing)
            } else {
                merged.append(newApp)
            }
        }

        // Sort: favorites first, then alphabetically
        merged.sort { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        activeApps = merged
    }

    /// Update the visible apps list including favorites that may not be active.
    private func updateVisibleApps() {
        var visible = activeApps

        // Add favorited apps from settings that aren't currently active
        let activeIDs = Set(activeApps.map(\.bundleID))
        let settings = SettingsStore.shared.perAppSettings

        for (bundleID, appSettings) in settings where appSettings.isFavorite {
            if !activeIDs.contains(bundleID) {
                let (name, icon) = BundleIDResolver.resolve(bundleID: bundleID, pid: 0)
                let ghostApp = AudioApp(
                    processObjectID: AudioObjectID(kAudioObjectUnknown),
                    bundleID: bundleID,
                    pid: 0,
                    name: name,
                    icon: icon
                )
                ghostApp.isRunningOutput = false
                ghostApp.isFavorite = true
                ghostApp.volume = appSettings.volume
                ghostApp.isMuted = appSettings.isMuted
                ghostApp.outputDeviceUID = appSettings.outputDeviceUID
                visible.append(ghostApp)
            }
        }

        // Sort: favorites first, then active, then alphabetically
        visible.sort { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            if a.isRunningOutput != b.isRunningOutput { return a.isRunningOutput }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        allVisibleApps = visible
    }

    // MARK: - Listeners

    /// Install listeners for process list changes.
    private func installListeners() {
        let queue = DispatchQueue.main

        // Process list changed (app starts/stops producing audio)
        if let token = try? addPropertyListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: makePropertyAddress(selector: kAudioHardwarePropertyProcessObjectList),
            queue: queue,
            block: { [weak self] _, _ in
                Task { @MainActor in
                    self?.refreshProcesses()
                }
            }
        ) {
            listenerTokens.append(token)
        }
    }
}
