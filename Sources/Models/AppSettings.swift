// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import Foundation

/// Per-application audio settings, persisted across app relaunches.
///
/// Keyed by bundle identifier so settings survive process restarts
/// and even system reboots.
struct PerAppSettings: Codable, Sendable {
    /// Volume level (0.0–2.0, where 1.0 = 100%).
    var volume: Float = 1.0

    /// Whether the app is muted.
    var isMuted: Bool = false

    /// UID of the preferred output device, or nil for system default.
    var outputDeviceUID: String? = nil

    /// Whether this app is pinned as a favorite.
    var isFavorite: Bool = false
}

/// Global application settings.
struct GlobalSettings: Codable, Sendable {
    /// Whether the onboarding flow has been completed.
    var hasCompletedOnboarding: Bool = false

    /// Whether to launch at login.
    var launchAtLogin: Bool = false

    /// Whether to show the level meters in the panel.
    var showLevelMeters: Bool = true

    /// Whether to show inactive (non-audio-producing) favorite apps.
    var showFavorites: Bool = true
}

/// Manages reading and writing settings to UserDefaults.
///
/// Thread-safe via `@MainActor` — all UI-driven settings changes
/// originate from the main thread anyway.
@MainActor
final class SettingsStore {

    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private let perAppKey = "com.opensoundsource.perAppSettings"
    private let globalKey = "com.opensoundsource.globalSettings"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Per-App Settings

    /// All per-app settings keyed by bundle identifier.
    private(set) var perAppSettings: [String: PerAppSettings] = [:]

    /// Get settings for a specific app. Returns defaults if none saved.
    func settings(for bundleID: String) -> PerAppSettings {
        perAppSettings[bundleID] ?? PerAppSettings()
    }

    /// Update settings for a specific app and persist.
    func updateSettings(for bundleID: String, _ update: (inout PerAppSettings) -> Void) {
        var settings = self.settings(for: bundleID)
        update(&settings)
        perAppSettings[bundleID] = settings
        savePerAppSettings()
    }

    /// Remove settings for an app (e.g., when un-favoriting and app is gone).
    func removeSettings(for bundleID: String) {
        perAppSettings.removeValue(forKey: bundleID)
        savePerAppSettings()
    }

    // MARK: - Global Settings

    private(set) var globalSettings: GlobalSettings = GlobalSettings()

    func updateGlobalSettings(_ update: (inout GlobalSettings) -> Void) {
        update(&globalSettings)
        saveGlobalSettings()
    }

    // MARK: - Persistence

    func load() {
        // Load per-app settings
        if let data = defaults.data(forKey: perAppKey),
           let decoded = try? decoder.decode([String: PerAppSettings].self, from: data) {
            perAppSettings = decoded
        }

        // Load global settings
        if let data = defaults.data(forKey: globalKey),
           let decoded = try? decoder.decode(GlobalSettings.self, from: data) {
            globalSettings = decoded
        }
    }

    private func savePerAppSettings() {
        if let data = try? encoder.encode(perAppSettings) {
            defaults.set(data, forKey: perAppKey)
        }
    }

    private func saveGlobalSettings() {
        if let data = try? encoder.encode(globalSettings) {
            defaults.set(data, forKey: globalKey)
        }
    }

    private init() {
        load()
    }
}
