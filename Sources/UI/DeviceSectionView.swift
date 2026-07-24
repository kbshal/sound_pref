// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import SwiftUI

/// Collapsible section showing device information and controls.
/// Matches the HTML mockup's `.section` styling.
struct DeviceSectionView: View {
    let title: String
    let icon: String // Optional: HTML didn't have an icon for System Output, but we can keep it or hide it.
    let device: AudioDevice?
    let allDevices: [AudioDevice]
    var onDeviceSelected: ((AudioDevice) -> Void)? = nil
    var onVolumeChanged: ((Float) -> Void)? = nil
    var onMuteToggled: ((Bool) -> Void)? = nil

    @State private var volume: Float = 1.0
    @State private var isMuted: Bool = false
    @State private var selectedDeviceUID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Title
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.secondary)
                .tracking(0.5)

            if let device {
                // Device Dropdown
                if allDevices.count > 1 {
                    DevicePickerMenu(
                        selectedDeviceUID: $selectedDeviceUID,
                        devices: allDevices,
                        defaultDevice: device,
                        onDeviceChanged: { uid in
                            if let uid, let selected = allDevices.first(where: { $0.uid == uid }) {
                                onDeviceSelected?(selected)
                            }
                        }
                    )
                }

                // Volume Slider row
                HStack(spacing: 8) {
                    Button {
                        isMuted.toggle()
                        onMuteToggled?(isMuted)
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(isMuted ? Color.red : Color.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)

                    VolumeSlider(
                        value: $volume,
                        style: .gray, // HTML uses gray style for system volume
                        isMuted: isMuted,
                        onEditingChanged: { editing in
                            if !editing {
                                onVolumeChanged?(volume)
                            }
                        }
                    )
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
        .onAppear {
            if let device {
                volume = device.volume
                isMuted = device.isMuted
                selectedDeviceUID = device.uid
            }
        }
        .onChange(of: device?.volume) { _, newValue in
            if let v = newValue { volume = v }
        }
        .onChange(of: device?.isMuted) { _, newValue in
            if let m = newValue { isMuted = m }
        }
        .onChange(of: device?.uid) { _, newUID in
            selectedDeviceUID = newUID
        }
    }
}
