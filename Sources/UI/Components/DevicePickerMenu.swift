// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import SwiftUI

/// A sleek dropdown menu for selecting an output device.
///
/// Matches the HTML mockup's dropdown style.
struct DevicePickerMenu: View {
    @Binding var selectedDeviceUID: String?
    let devices: [AudioDevice]
    let defaultDevice: AudioDevice?
    var onDeviceChanged: ((String?) -> Void)? = nil

    @State private var isHovered: Bool = false

    var body: some View {
        Menu {
            // System Default option
            Button {
                selectedDeviceUID = nil
                onDeviceChanged?(nil)
            } label: {
                HStack {
                    if selectedDeviceUID == nil {
                        Image(systemName: "checkmark")
                    }
                    Text("System Default")
                    if let defaultDevice {
                        Text("(\(defaultDevice.name))")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Individual devices
            ForEach(devices) { device in
                Button {
                    selectedDeviceUID = device.uid
                    onDeviceChanged?(device.uid)
                } label: {
                    HStack {
                        if selectedDeviceUID == device.uid {
                            Image(systemName: "checkmark")
                        }
                        Image(systemName: device.systemImageName)
                        Text(device.name)
                    }
                }
            }
        } label: {
            HStack {
                Text(currentDeviceName)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var currentDeviceName: String {
        if let uid = selectedDeviceUID,
           let device = devices.first(where: { $0.uid == uid }) {
            return device.name
        }
        return "System Default"
    }
}
