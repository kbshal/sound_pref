// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import SwiftUI

/// A single row in the app list representing one audio-producing application.
/// Matches the `.app-row` HTML mockup styling.
struct AppRowView: View {
    @Bindable var app: AudioApp
    let outputDevices: [AudioDevice]
    let defaultOutputDevice: AudioDevice?
    var showLevelMeter: Bool = true // We can keep this if they enable it in settings

    var onVolumeChanged: ((Float) -> Void)? = nil
    var onMuteToggled: ((Bool) -> Void)? = nil
    var onOutputDeviceChanged: ((String?) -> Void)? = nil
    var onFavoriteToggled: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top section: Icon, Name, Slider
            HStack(spacing: 12) {
                // App Icon
                appIcon
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 1)

                // App Info & Controls
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(app.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(app.isRunningOutput ? .primary : .secondary)
                            .lineLimit(1)
                        
                        if app.isRunningOutput {
                            EqualizerBarsView(level: app.peakLevel, isPlaying: !app.isMuted)
                                .padding(.leading, 4)
                        } else {
                            Text("Not playing")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Button {
                            onFavoriteToggled?()
                        } label: {
                            Image(systemName: app.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundStyle(app.isFavorite ? .yellow : .secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    // Slider row
                    HStack(spacing: 8) {
                        Button {
                            let newMuted = !app.isMuted
                            app.isMuted = newMuted
                            onMuteToggled?(newMuted)
                        } label: {
                            Image(systemName: muteIcon)
                                .font(.system(size: 12))
                                .foregroundStyle(app.isMuted ? .red : .secondary)
                                .frame(width: 16)
                        }
                        .buttonStyle(.plain)

                        VolumeSlider(
                            value: Binding(
                                get: { app.volume },
                                set: { newValue in
                                    app.volume = newValue
                                    onVolumeChanged?(newValue)
                                }
                            ),
                            style: .accent, // HTML apps use the accent slider
                            isMuted: app.isMuted,
                            onEditingChanged: { editing in
                                if !editing {
                                    onVolumeChanged?(app.volume)
                                }
                            }
                        )
                    }
                }
            }

            // Bottom section: Output Device Picker (Indented)
            HStack {
                Spacer()
                    .frame(width: 44) // 32 (icon) + 12 (spacing)

                DevicePickerMenu(
                    selectedDeviceUID: Binding(
                        get: { app.outputDeviceUID },
                        set: { newValue in
                            app.outputDeviceUID = newValue
                            onOutputDeviceChanged?(newValue)
                        }
                    ),
                    devices: outputDevices,
                    defaultDevice: defaultOutputDevice
                )
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .opacity(app.isRunningOutput ? 1.0 : 0.6)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var appIcon: some View {
        if let nsImage = app.icon {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
    }

    private var muteIcon: String {
        if app.isMuted {
            return "speaker.slash.fill"
        } else if app.volume == 0 {
            return "speaker.fill"
        } else if app.volume < 0.5 {
            return "speaker.wave.1.fill"
        } else if app.volume < 1.5 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}
