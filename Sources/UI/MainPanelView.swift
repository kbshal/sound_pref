// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import SwiftUI

/// The main panel view displayed in the menu bar popover.
/// Matches the `.panel` HTML mockup styling.
struct MainPanelView: View {
    let deviceManager: AudioDeviceManager
    let processDiscovery: AudioProcessDiscovery
    let audioRouter: AudioRouter

    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // System Output Section
                    DeviceSectionView(
                        title: "System Output",
                        icon: "speaker.wave.2.fill",
                        device: deviceManager.defaultOutputDevice,
                        allDevices: deviceManager.outputDevices,
                        onDeviceSelected: { device in
                            try? deviceManager.setDefaultOutputDevice(device)
                        },
                        onVolumeChanged: { volume in
                            if let device = deviceManager.defaultOutputDevice {
                                try? deviceManager.setDeviceVolume(deviceID: device.id, volume: volume)
                            }
                        },
                        onMuteToggled: { muted in
                            if let device = deviceManager.defaultOutputDevice {
                                try? deviceManager.setDeviceMute(deviceID: device.id, muted: muted)
                            }
                        }
                    )

                    // Input Device Section
                    DeviceSectionView(
                        title: "System Input",
                        icon: "mic.fill",
                        device: deviceManager.defaultInputDevice,
                        allDevices: deviceManager.inputDevices,
                        onDeviceSelected: { device in
                            try? deviceManager.setDefaultInputDevice(device)
                        }
                    )

                    // Applications Section
                    appListSection
                }
            }

            // Footer
            footerView
        }
        .padding(16)
        .frame(width: 340) // Matched to HTML width
        .frame(maxHeight: 680)
        // Simulate glassmorphism
        .background(
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("SoundPref")
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(.primary)

            Spacer()
            
            // Engine toggle / Status
            Button {
                audioRouter.isEngineEnabled.toggle()
            } label: {
                Image(systemName: audioRouter.isEngineEnabled ? "waveform" : "waveform.slash")
                    .font(.system(size: 14))
                    .foregroundStyle(audioRouter.isEngineEnabled ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(audioRouter.isEngineEnabled ? "Disable audio engine" : "Enable audio engine")

            // Settings Button
            Button {
                SettingsWindowPresenter.shared.show()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.001)) // clickable area
                    )
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    // MARK: - App List

    private var appListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Applications")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.secondary)
                .tracking(0.5)

            VStack(spacing: 8) {
                if filteredApps.isEmpty {
                    emptyStateView
                } else {
                    ForEach(Array(filteredApps.enumerated()), id: \.element.id) { index, app in
                        AppRowView(
                            app: app,
                            outputDevices: deviceManager.outputDevices,
                            defaultOutputDevice: deviceManager.defaultOutputDevice,
                            showLevelMeter: SettingsStore.shared.globalSettings.showLevelMeters,
                            onVolumeChanged: { volume in
                                audioRouter.setVolume(for: app, volume: volume)
                            },
                            onMuteToggled: { muted in
                                audioRouter.setMuted(for: app, muted: muted)
                            },
                            onOutputDeviceChanged: { deviceUID in
                                audioRouter.setOutputDevice(for: app, deviceUID: deviceUID)
                            },
                            onFavoriteToggled: {
                                audioRouter.toggleFavorite(for: app)
                            }
                        )
                        
                        // Add divider between apps, but not after the last one
                        if index < filteredApps.count - 1 {
                            Divider()
                                .opacity(0.2)
                                .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.zzz")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)

            Text("No apps producing audio")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var filteredApps: [AudioApp] {
        let apps = processDiscovery.allVisibleApps
        guard SettingsStore.shared.globalSettings.showFavorites else {
            return apps.filter { $0.isRunningOutput }
        }
        return apps
    }
}
