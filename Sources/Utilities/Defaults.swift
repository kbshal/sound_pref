// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import Foundation

/// Centralized UserDefaults key constants.
///
/// All keys are namespaced under `com.soundpref.` to avoid collisions.
enum DefaultsKey {
    static let perAppSettings = "com.soundpref.perAppSettings"
    static let globalSettings = "com.soundpref.globalSettings"
    static let hasCompletedOnboarding = "com.soundpref.hasCompletedOnboarding"
    static let launchAtLogin = "com.soundpref.launchAtLogin"
    static let lastSelectedOutputDeviceUID = "com.soundpref.lastSelectedOutputDeviceUID"
    static let panelWidth = "com.soundpref.panelWidth"
}
