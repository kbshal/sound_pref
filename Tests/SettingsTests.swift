// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import Testing

@Suite("Settings Tests")
struct SettingsTests {
    @Test("PerAppSettings defaults")
    func perAppSettingsDefaults() {
        let settings = PerAppSettings()
        #expect(settings.volume == 1.0)
        #expect(settings.isMuted == false)
        #expect(settings.outputDeviceUID == nil)
        #expect(settings.isFavorite == false)
    }

    @Test("PerAppSettings encoding/decoding")
    func perAppSettingsRoundTrip() throws {
        var settings = PerAppSettings()
        settings.volume = 1.5
        settings.isMuted = true
        settings.outputDeviceUID = "test-device-uid"
        settings.isFavorite = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PerAppSettings.self, from: data)

        #expect(decoded.volume == 1.5)
        #expect(decoded.isMuted == true)
        #expect(decoded.outputDeviceUID == "test-device-uid")
        #expect(decoded.isFavorite == true)
    }

    @Test("GlobalSettings defaults")
    func globalSettingsDefaults() {
        let settings = GlobalSettings()
        #expect(settings.hasCompletedOnboarding == false)
        #expect(settings.launchAtLogin == false)
        #expect(settings.showLevelMeters == true)
        #expect(settings.showFavorites == true)
    }
}
