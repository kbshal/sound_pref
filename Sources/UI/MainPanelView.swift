// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import SwiftUI

/// The main panel view displayed in the menu bar popover.
///
/// Layout mirrors SoundSource: device sections at top, followed by
/// a scrollable list of per-app audio controls.
struct MainPanelView: View {
    let deviceManager: AudioDeviceManager
    let processDiscovery: AudioProcessDiscovery
    let audioRouter: AudioRouter

    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with app title
            headerView

            Divider()
                .opacity(0.3)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 2) {
                    // Output Device Section
                    DeviceSectionView(
                        title: "Output",
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

                    thinDivider

                    // Input Device Section
                    DeviceSectionView(
                        title: "Input",
                        icon: "mic.fill",
                        device: deviceManager.defaultInputDevice,
                        allDevices: deviceManager.inputDevices,
                        onDeviceSelected: { device in
                            try? deviceManager.setDefaultInputDevice(device)
                        }
                    )

                    sectionDivider

                    // Per-App Audio Controls
                    appListSection
                }
            }

            Divider()
                .opacity(0.3)

            // Footer
            footerView
        }
        .frame(width: 340)
        .frame(maxHeight: 520)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.accentColor)

            Text("OpenSoundSource")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            // Engine toggle
            Button {
                audioRouter.isEngineEnabled.toggle()
            } label: {
                Image(systemName: audioRouter.isEngineEnabled ? "power.circle.fill" : "power.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(audioRouter.isEngineEnabled ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(audioRouter.isEngineEnabled ? "Disable audio engine" : "Enable audio engine")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - App List

    private var appListSection: some View {
        VStack(spacing: 2) {
            // Section header
            HStack {
                Image(systemName: "app.dashed")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.accentColor)
                    .frame(width: 16)

                Text("Applications")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(filteredApps.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)

            if filteredApps.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredApps) { app in
                    AppRowView(
                        app: app,
                        outputDevices: deviceManager.outputDevices,
                        defaultOutputDevice: deviceManager.defaultOutputDevice,
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
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.zzz")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)

            Text("No apps producing audio")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("Play something in any app and it will appear here.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button {
                // Open about / settings
                NSApp.orderFrontStandardAboutPanel()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("v0.1.0")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit OpenSoundSource")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private var filteredApps: [AudioApp] {
        processDiscovery.allVisibleApps
    }

    private var thinDivider: some View {
        Divider()
            .opacity(0.15)
            .padding(.horizontal, 10)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(height: 1)
            .padding(.vertical, 2)
    }
}
