// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import SwiftUI

enum VolumeSliderStyle {
    case accent
    case gray
}

/// Custom sleek volume slider that matches the SoundPref HTML mockup.
struct VolumeSlider: View {
    @Binding var value: Float
    var style: VolumeSliderStyle = .accent
    var isMuted: Bool = false
    var onEditingChanged: ((Bool) -> Void)? = nil

    @State private var isHovered: Bool = false
    
    private let trackHeight: CGFloat = 4
    private let thumbDiameter: CGFloat = 12
    private let thumbHoverScale: CGFloat = 1.3

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let normalizedValue = CGFloat(max(0.0, min(1.0, value)))
            let thumbX = normalizedValue * width

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: trackHeight)

                // Filled track
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(0, thumbX), height: trackHeight)
                    .opacity(isMuted ? 0.3 : 1.0)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .scaleEffect(isHovered ? thumbHoverScale : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
                    .position(
                        x: max(thumbDiameter / 2, min(width - thumbDiameter / 2, thumbX)),
                        y: geometry.size.height / 2
                    )
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newValue = Float(drag.location.x / width)
                        let clamped = max(0.0, min(1.0, newValue))
                        value = clamped

                        onEditingChanged?(true)
                    }
                    .onEnded { _ in
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: thumbDiameter * thumbHoverScale) // ensure room for hover scale
    }

    private var fillColor: Color {
        if style == .accent {
            return .accentColor
        } else {
            return Color.white.opacity(0.8)
        }
    }
}

// MARK: - Volume Label

/// A small label showing the current volume percentage.
struct VolumeLabel: View {
    let value: Float

    var body: some View {
        Text(volumeText)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.secondary)
            .frame(width: 32, alignment: .trailing)
    }

    private var volumeText: String {
        let percentage = Int(value * 100)
        return "\(percentage)%"
    }
}
