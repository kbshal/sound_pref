// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import SwiftUI

/// A single row in the app list representing one audio-producing application.
///
/// Contains: app icon, name, level meter, volume slider, mute button,
/// output device picker, and favorite toggle.
struct AppRowView: View {
    @Bindable var app: AudioApp
    let outputDevices: [AudioDevice]
    let defaultOutputDevice: AudioDevice?

    var onVolumeChanged: ((Float) -> Void)? = nil
    var onMuteToggled: ((Bool) -> Void)? = nil
    var onOutputDeviceChanged: ((String?) -> Void)? = nil
    var onFavoriteToggled: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 4) {
            // Top row: icon, name, controls
            HStack(spacing: 8) {
                // App icon
                appIcon
                    .frame(width: 28, height: 28)

                // App name
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(app.isRunningOutput ? .primary : .secondary)
                        .lineLimit(1)

                    if !app.isRunningOutput {
                        Text("Not playing")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Favorite button
                Button {
                    onFavoriteToggled?()
                } label: {
                    Image(systemName: app.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 10))
                        .foregroundStyle(app.isFavorite ? .yellow : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(app.isFavorite ? "Remove from favorites" : "Add to favorites")

                // Output device picker
                DevicePickerMenu(
                    selectedDeviceUID: Binding(
                        get: { app.outputDeviceUID },
                        set: { newValue in
                            app.outputDeviceUID = newValue
                            onOutputDeviceChanged?(newValue)
                        }
                    ),
                    devices: outputDevices,
                    defaultDevice: defaultOutputDevice,
                    onDeviceChanged: onOutputDeviceChanged
                )
            }

            // Level meter
            LevelMeterView(
                level: app.peakLevel,
                isActive: app.isRunningOutput && !app.isMuted
            )
            .padding(.horizontal, 36)

            // Bottom row: mute button, volume slider, volume label
            HStack(spacing: 6) {
                // Mute button
                Button {
                    let newMuted = !app.isMuted
                    app.isMuted = newMuted
                    onMuteToggled?(newMuted)
                } label: {
                    Image(systemName: muteIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(app.isMuted ? .red : .secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .help(app.isMuted ? "Unmute" : "Mute")

                // Volume slider
                VolumeSlider(
                    value: Binding(
                        get: { app.volume },
                        set: { newValue in
                            app.volume = newValue
                            onVolumeChanged?(newValue)
                        }
                    ),
                    isMuted: app.isMuted,
                    onEditingChanged: { editing in
                        if !editing {
                            onVolumeChanged?(app.volume)
                        }
                    }
                )

                // Volume percentage label
                VolumeLabel(value: app.volume)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
        )
        .opacity(app.isRunningOutput ? 1.0 : 0.6)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var appIcon: some View {
        if let nsImage = app.icon {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
