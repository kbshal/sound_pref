// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import SwiftUI

/// Custom volume slider with a detent at 100% and boost zone above.
///
/// The slider covers 0–200% (0.0–2.0). The 100% mark has a subtle
/// visual detent so the user can easily find "normal" volume.
/// Values above 100% are shown in an accent color to indicate boost.
struct VolumeSlider: View {
    @Binding var value: Float
    var isMuted: Bool = false
    var onEditingChanged: ((Bool) -> Void)? = nil

    /// The height of the slider track.
    private let trackHeight: CGFloat = 4
    /// The diameter of the thumb.
    private let thumbDiameter: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let normalizedValue = CGFloat(value / 2.0) // 0.0–1.0 for 0–200%
            let thumbX = normalizedValue * width
            let detentX = width * 0.5 // 100% mark

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: trackHeight)

                // Filled track
                Capsule()
                    .fill(fillGradient(boostActive: value > 1.0))
                    .frame(width: max(0, thumbX), height: trackHeight)
                    .opacity(isMuted ? 0.3 : 1.0)

                // 100% detent marker
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: trackHeight + 6)
                    .position(x: detentX, y: geometry.size.height / 2)

                // Thumb
                Circle()
                    .fill(isMuted ? Color.gray : Color.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .position(
                        x: max(thumbDiameter / 2, min(width - thumbDiameter / 2, thumbX)),
                        y: geometry.size.height / 2
                    )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newValue = Float(drag.location.x / width) * 2.0
                        let clamped = max(0.0, min(2.0, newValue))

                        // Snap to 100% detent within a small range
                        if abs(clamped - 1.0) < 0.04 {
                            value = 1.0
                        } else {
                            value = clamped
                        }

                        onEditingChanged?(true)
                    }
                    .onEnded { _ in
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: thumbDiameter + 4)
    }

    /// Gradient for the filled portion — normal blue up to 100%, orange/amber above.
    private func fillGradient(boostActive: Bool) -> LinearGradient {
        if boostActive {
            return LinearGradient(
                colors: [.accentColor, .accentColor, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [.accentColor, .accentColor],
                startPoint: .leading,
                endPoint: .trailing
            )
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
            .foregroundStyle(value > 1.0 ? Color.orange : Color.secondary)
            .frame(width: 36, alignment: .trailing)
    }

    private var volumeText: String {
        let percentage = Int(value * 100)
        return "\(percentage)%"
    }
}

#Preview {
    VStack(spacing: 20) {
        VolumeSlider(value: .constant(0.5))
        VolumeSlider(value: .constant(1.0))
        VolumeSlider(value: .constant(1.5))
        VolumeSlider(value: .constant(1.0), isMuted: true)
    }
    .padding()
    .frame(width: 200)
    .background(.black)
}
