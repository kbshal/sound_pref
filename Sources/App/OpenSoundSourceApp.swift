// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import SwiftUI

/// OpenSoundSource — A free, open-source macOS audio control utility.
///
/// This is a menu-bar-only app (LSUIElement). The main UI is a popover
/// panel managed by `MenuBarController`. There is no main window.
@main
struct OpenSoundSourceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window (accessible via the gear icon in the panel)
        Settings {
            SettingsView()
        }
    }
}

/// Placeholder settings view.
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("OpenSoundSource Settings")
                .font(.title2)
                .fontWeight(.semibold)

            GroupBox("General") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at login", isOn: .constant(false))
                    Toggle("Show level meters", isOn: .constant(true))
                    Toggle("Show inactive favorites", isOn: .constant(true))
                }
                .padding(8)
            }

            GroupBox("About") {
                VStack(spacing: 4) {
                    Text("Version 0.1.0 (MVP)")
                        .font(.subheadline)
                    Text("GPL-3.0 License")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Link("GitHub Repository", destination: URL(string: "https://github.com/opensoundsource")!)
                        .font(.caption)
                }
                .padding(8)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 350, height: 280)
    }
}
