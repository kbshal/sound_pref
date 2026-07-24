// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import AppKit
import ServiceManagement
import SwiftUI

/// SoundPref — A free, open-source macOS audio control utility.
///
/// This is a menu-bar-only app (LSUIElement). The main UI is a popover
/// panel managed by `MenuBarController`. There is no main window.
@main
struct SoundPrefApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window (accessible via the gear icon in the panel)
        Settings {
            SettingsView()
        }
    }
}

/// Presents the settings window from the menu bar panel.
///
/// A menu-bar-only (LSUIElement) app can't reliably use the private
/// `showSettingsWindow:` action, so we manage our own window.
@MainActor
final class SettingsWindowPresenter {

    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SoundPref Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Settings view with working controls backed by `SettingsStore`.
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("SoundPref Settings")
                .font(.title2)
                .fontWeight(.semibold)

            GroupBox("General") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                    Toggle("Show level meters", isOn: globalSettingBinding(\.showLevelMeters))
                    Toggle("Show inactive favorites", isOn: globalSettingBinding(\.showFavorites))
                }
                .padding(8)
            }

            GroupBox("About") {
                VStack(spacing: 4) {
                    Text("Version 0.1.0")
                        .font(.subheadline)
                    Text("GPL-3.0 License")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Link("GitHub Repository", destination: URL(string: "https://github.com/kbshal/sound_pref")!)
                        .font(.caption)
                }
                .padding(8)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 360, height: 300)
    }

    // MARK: - Bindings

    /// Binding into a Bool field of the persisted global settings.
    private func globalSettingBinding(_ keyPath: WritableKeyPath<GlobalSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: {
                MainActor.assumeIsolated {
                    SettingsStore.shared.globalSettings[keyPath: keyPath]
                }
            },
            set: { newValue in
                MainActor.assumeIsolated {
                    SettingsStore.shared.updateGlobalSettings { $0[keyPath: keyPath] = newValue }
                }
            }
        )
    }

    /// Launch-at-login also registers/unregisters with the system.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: {
                MainActor.assumeIsolated {
                    SettingsStore.shared.globalSettings.launchAtLogin
                }
            },
            set: { enabled in
                MainActor.assumeIsolated {
                    SettingsStore.shared.updateGlobalSettings { $0.launchAtLogin = enabled }
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Registration can fail for unsigned dev builds; the
                        // preference is still saved and applied on next try.
                    }
                }
            }
        )
    }
}
