// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import CoreAudio
import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: "com.soundpref", category: "AudioRouter")

/// Orchestrates per-app audio routing by managing ProcessTapManagers.
///
/// The AudioRouter is the bridge between the UI (which sets volume, mute,
/// and output device per app) and the audio engine (which creates taps
/// and processes audio). It maintains a dictionary of active taps keyed
/// by bundle ID.
@MainActor
@Observable
final class AudioRouter {

    /// Active tap managers keyed by bundle identifier.
    private(set) var activeTaps: [String: ProcessTapManager] = [:]

    /// Whether the audio engine is globally enabled.
    var isEngineEnabled: Bool = true {
        didSet {
            if isEngineEnabled {
                // Re-enable: recreate taps for all known apps
                reactivateAllTaps()
            } else {
                // Disable: stop all taps
                stopAllTaps()
            }
        }
    }

    /// Reference to process discovery for getting process object IDs.
    private let processDiscovery: AudioProcessDiscovery

    /// Reference to device manager for resolving device UIDs.
    private let deviceManager: AudioDeviceManager

    // MARK: - Initialization

    init(processDiscovery: AudioProcessDiscovery, deviceManager: AudioDeviceManager) {
        self.processDiscovery = processDiscovery
        self.deviceManager = deviceManager
    }

    // Note: no explicit deinit needed — releasing `activeTaps` deallocates each
    // ProcessTapManager, whose own deinit calls stop() to tear down its tap.

    // MARK: - Per-App Control

    /// Ensure a tap exists for the given app and set its volume.
    func setVolume(for app: AudioApp, volume: Float) {
        app.volume = volume

        // Persist
        SettingsStore.shared.updateSettings(for: app.bundleID) { settings in
            settings.volume = volume
        }

        // Apply to active tap
        if let tap = activeTaps[app.bundleID] {
            tap.setGain(volume)
        } else {
            ensureTap(for: app)
        }
    }

    /// Set the mute state for an app.
    func setMuted(for app: AudioApp, muted: Bool) {
        app.isMuted = muted

        // Persist
        SettingsStore.shared.updateSettings(for: app.bundleID) { settings in
            settings.isMuted = muted
        }

        // Apply to active tap
        if let tap = activeTaps[app.bundleID] {
            tap.setMuted(muted)
        } else {
            ensureTap(for: app)
        }
    }

    /// Set the output device for an app.
    func setOutputDevice(for app: AudioApp, deviceUID: String?) {
        app.outputDeviceUID = deviceUID

        // Persist
        SettingsStore.shared.updateSettings(for: app.bundleID) { settings in
            settings.outputDeviceUID = deviceUID
        }

        // This requires restarting the tap with the new device
        if let tap = activeTaps[app.bundleID] {
            do {
                try tap.setOutputDevice(uid: deviceUID)
            } catch {
                logger.error("Failed to change output device for \(app.bundleID): \(error)")
                // Try to restart from scratch
                removeTap(for: app)
                ensureTap(for: app)
            }
        } else {
            ensureTap(for: app)
        }
    }

    /// Toggle favorite status for an app.
    func toggleFavorite(for app: AudioApp) {
        app.isFavorite.toggle()

        SettingsStore.shared.updateSettings(for: app.bundleID) { settings in
            settings.isFavorite = app.isFavorite
        }
    }

    // MARK: - Tap Management

    /// Ensure a tap exists for the given app. Creates one if needed.
    func ensureTap(for app: AudioApp) {
        guard isEngineEnabled else { return }
        guard app.isRunningOutput else { return }
        // Never tap our own process: we render other apps' redirected audio,
        // so a self-tap would mute everything we play (feedback → silence).
        guard app.pid != ProcessInfo.processInfo.processIdentifier else { return }
        guard activeTaps[app.bundleID] == nil else { return }
        guard app.processObjectID != AudioObjectID(kAudioObjectUnknown) else { return }

        // Only create a tap if the user has customized something
        // (volume != 1.0, muted, or custom output device)
        // Otherwise, let the audio pass through normally
        let needsTap = app.volume != 1.0 || app.isMuted || app.outputDeviceUID != nil

        guard needsTap else { return }

        let tap = ProcessTapManager(
            bundleID: app.bundleID,
            processObjectID: app.processObjectID,
            muteSource: app.outputDeviceUID != nil, // Only mute source if redirecting
            targetOutputDeviceUID: app.outputDeviceUID
        )

        // Wire up level meter callback
        tap.onPeakLevelUpdate = { [weak app] level in
            Task { @MainActor in
                app?.peakLevel = level
            }
        }

        do {
            try tap.start()
            tap.setGain(app.volume)
            tap.setMuted(app.isMuted)
            activeTaps[app.bundleID] = tap
            app.isTapped = true
            logger.info("Started tap for \(app.bundleID)")
        } catch {
            logger.error("Failed to start tap for \(app.bundleID): \(error)")
        }
    }

    /// Remove and clean up the tap for an app.
    func removeTap(for app: AudioApp) {
        if let tap = activeTaps.removeValue(forKey: app.bundleID) {
            tap.stop()
            app.isTapped = false
            logger.info("Stopped tap for \(app.bundleID)")
        }
    }

    /// Activate taps for all apps that need them.
    func reactivateAllTaps() {
        for app in processDiscovery.activeApps {
            ensureTap(for: app)
        }
    }

    /// Stop all active taps.
    func stopAllTaps() {
        for (bundleID, tap) in activeTaps {
            tap.stop()
            logger.info("Stopped tap for \(bundleID)")
        }
        activeTaps.removeAll()

        // Reset tapped state on all apps
        for app in processDiscovery.activeApps {
            app.isTapped = false
        }
    }

    /// Called when the process list changes. Cleans up taps for processes
    /// that no longer exist and creates taps for new ones that need them.
    func syncWithProcessList() {
        let activeIDs = Set(processDiscovery.activeApps.map(\.bundleID))

        // Remove taps for apps that are no longer producing audio
        let staleIDs = activeTaps.keys.filter { !activeIDs.contains($0) }
        for bundleID in staleIDs {
            if let tap = activeTaps.removeValue(forKey: bundleID) {
                tap.stop()
                logger.info("Cleaned up stale tap for \(bundleID)")
            }
        }

        // Ensure taps for apps that need them
        for app in processDiscovery.activeApps {
            ensureTap(for: app)
        }
    }
}
