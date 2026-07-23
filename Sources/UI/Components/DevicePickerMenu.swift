// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import SwiftUI

/// A compact dropdown menu for selecting an output device.
///
/// Shows the currently selected device (or "System Default") and
/// presents a menu of all available output devices.
struct DevicePickerMenu: View {
    /// The currently selected device UID (nil = system default).
    @Binding var selectedDeviceUID: String?

    /// All available output devices.
    let devices: [AudioDevice]

    /// The system default device (for display when selection is nil).
    let defaultDevice: AudioDevice?

    /// Callback when device selection changes.
    var onDeviceChanged: ((String?) -> Void)? = nil

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
            HStack(spacing: 3) {
                Image(systemName: currentDeviceIcon)
                    .font(.system(size: 10))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundStyle(selectedDeviceUID != nil ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    /// Icon for the currently selected device.
    private var currentDeviceIcon: String {
        if let uid = selectedDeviceUID,
           let device = devices.first(where: { $0.uid == uid }) {
            return device.systemImageName
        }
        return defaultDevice?.systemImageName ?? "speaker.wave.2"
    }
}
