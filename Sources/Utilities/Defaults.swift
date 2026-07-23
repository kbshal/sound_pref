// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import Foundation

/// Centralized UserDefaults key constants.
///
/// All keys are namespaced under `com.opensoundsource.` to avoid collisions.
enum DefaultsKey {
    static let perAppSettings = "com.opensoundsource.perAppSettings"
    static let globalSettings = "com.opensoundsource.globalSettings"
    static let hasCompletedOnboarding = "com.opensoundsource.hasCompletedOnboarding"
    static let launchAtLogin = "com.opensoundsource.launchAtLogin"
    static let lastSelectedOutputDeviceUID = "com.opensoundsource.lastSelectedOutputDeviceUID"
    static let panelWidth = "com.opensoundsource.panelWidth"
}
