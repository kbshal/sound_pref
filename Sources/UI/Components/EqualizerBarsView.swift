// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import SwiftUI

/// A small animated "equalizer" indicator (dancing bars) shown next to
/// apps that are currently playing audio.
///
/// When a real peak level is available (the app is tapped), bar amplitude
/// follows the level. Otherwise the bars animate with a pleasant default
/// motion so playing apps are still clearly identifiable.
struct EqualizerBarsView: View {
    /// Current peak level (0.0–1.0). 0 when unknown/untapped.
    let level: Float

    /// Whether the app is actively playing (drives the animation).
    var isPlaying: Bool = true

    private let barCount = 4
    private let barWidth: CGFloat = 2.5
    private let barSpacing: CGFloat = 1.5
    private let minBarHeight: CGFloat = 2
    private let maxBarHeight: CGFloat = 12

    // Per-bar animation speeds/phases so the bars move independently.
    private let speeds: [Double] = [9.3, 12.7, 10.1, 8.2]
    private let phases: [Double] = [0.0, 1.9, 3.4, 5.1]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(isPlaying ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                        .frame(width: barWidth, height: barHeight(index: index, time: time))
                }
            }
            .frame(height: maxBarHeight)
        }
    }

    /// Compute a bar's height from time-based oscillation scaled by level.
    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return minBarHeight }

        // Use the real peak level when we have one; otherwise animate
        // at a default amplitude so untapped apps still show motion.
        let amplitude = level > 0.001 ? CGFloat(min(level * 1.5, 1.0)) : 0.7

        let oscillation = 0.5 + 0.5 * sin(time * speeds[index % speeds.count] + phases[index % phases.count])
        return minBarHeight + amplitude * (maxBarHeight - minBarHeight) * CGFloat(oscillation)
    }
}
