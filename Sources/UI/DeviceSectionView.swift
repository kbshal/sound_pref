// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import SwiftUI

/// Collapsible section showing device information and controls.
///
/// Used for Output, Input, and Sound Effects device sections
/// at the top of the main panel.
struct DeviceSectionView: View {
    let title: String
    let icon: String
    let device: AudioDevice?
    let allDevices: [AudioDevice]
    var onDeviceSelected: ((AudioDevice) -> Void)? = nil
    var onVolumeChanged: ((Float) -> Void)? = nil
    var onMuteToggled: ((Bool) -> Void)? = nil

    @State private var isExpanded: Bool = true
    @State private var volume: Float = 1.0
    @State private var isMuted: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header — clickable to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.accentColor)
                        .frame(width: 16)

                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    if let device {
                        Text(device.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded, let device {
                VStack(spacing: 6) {
                    // Device selector menu
                    if allDevices.count > 1 {
                        Menu {
                            ForEach(allDevices) { dev in
                                Button {
                                    onDeviceSelected?(dev)
                                } label: {
                                    HStack {
                                        if dev.id == device.id {
                                            Image(systemName: "checkmark")
                                        }
                                        Image(systemName: dev.systemImageName)
                                        Text(dev.name)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: device.systemImageName)
                                    .font(.system(size: 12))
                                Text(device.name)
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.05))
                            )
                        }
                        .menuStyle(.borderlessButton)
                    }

                    // Volume control (for output devices with volume)
                    HStack(spacing: 6) {
                        Button {
                            isMuted.toggle()
                            onMuteToggled?(isMuted)
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(isMuted ? .red : .secondary)
                                .frame(width: 20)
                        }
                        .buttonStyle(.plain)

                        VolumeSlider(
                            value: $volume,
                            isMuted: isMuted,
                            onEditingChanged: { editing in
                                if !editing {
                                    onVolumeChanged?(volume)
                                }
                            }
                        )

                        VolumeLabel(value: volume)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            if let device {
                volume = device.volume
                isMuted = device.isMuted
            }
        }
        .onChange(of: device?.volume) { _, newValue in
            if let v = newValue { volume = v }
        }
        .onChange(of: device?.isMuted) { _, newValue in
            if let m = newValue { isMuted = m }
        }
    }
}
