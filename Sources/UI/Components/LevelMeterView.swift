// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import SwiftUI

/// A horizontal audio level meter that shows real-time peak levels.
///
/// The meter uses a green → yellow → red gradient to indicate level,
/// with smooth animation for rising levels and fast decay.
struct LevelMeterView: View {
    /// Current peak level (0.0–1.0).
    let level: Float

    /// Whether the meter is active (dimmed when muted or inactive).
    var isActive: Bool = true

    /// Height of the meter bar.
    private let barHeight: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fillWidth = CGFloat(level) * width

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: barHeight)

                // Filled level
                Capsule()
                    .fill(meterGradient)
                    .frame(width: max(0, fillWidth), height: barHeight)
                    .opacity(isActive ? 1.0 : 0.2)
            }
        }
        .frame(height: barHeight)
        .animation(.easeOut(duration: 0.08), value: level)
    }

    /// Green → Yellow → Red gradient for the meter fill.
    private var meterGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: 0.35, saturation: 0.8, brightness: 0.9), // Green
                Color(hue: 0.15, saturation: 0.9, brightness: 0.95), // Yellow
                Color(hue: 0.02, saturation: 0.9, brightness: 0.9),  // Red
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        LevelMeterView(level: 0.1)
        LevelMeterView(level: 0.5)
        LevelMeterView(level: 0.8)
        LevelMeterView(level: 1.0)
        LevelMeterView(level: 0.5, isActive: false)
    }
    .padding()
    .frame(width: 200)
    .background(.black)
}
