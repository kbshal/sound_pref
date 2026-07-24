// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import SwiftUI

/// First-launch onboarding view that walks the user through permissions.
///
/// Steps:
/// 1. Welcome — explains what the app does
/// 2. Grant System Audio Recording permission
/// 3. Explains the purple capture indicator
/// 4. "You're all set!" — dismisses to main panel
struct OnboardingView: View {
    @State private var currentStep: Int = 0
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                permissionStep.tag(1)
                captureIndicatorStep.tag(2)
                completionStep.tag(3)
            }
            .tabViewStyle(.automatic)

            // Navigation dots + Next button
            HStack {
                // Step indicators
                HStack(spacing: 6) {
                    ForEach(0..<4) { step in
                        Circle()
                            .fill(step == currentStep ? Color.accentColor : Color.white.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                // Next / Done button
                Button {
                    if currentStep < 3 {
                        withAnimation {
                            currentStep += 1
                        }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentStep < 3 ? "Next" : "Get Started")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 400, height: 340)
        .background(.ultraThinMaterial)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, isActive: true)

            Text("Welcome to SoundPref")
                .font(.system(size: 20, weight: .bold))

            Text("Control every app's audio right from your menu bar.\nAdjust volume, mute, and route apps to different speakers — all for free.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()
        }
    }

    private var permissionStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Audio Recording Permission")
                .font(.system(size: 18, weight: .bold))

            Text("SoundPref needs permission to capture audio from other apps.\n\nWhen prompted, click **Allow** to enable per-app volume and routing.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Text("All audio processing is 100% local.\nNothing is recorded or sent anywhere.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private var captureIndicatorStep: some View {
        VStack(spacing: 16) {
            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 12, height: 12)
                    .shadow(color: .purple.opacity(0.5), radius: 4)

                Text("•")
                    .font(.system(size: 20))
                    .foregroundStyle(.purple)
                    .opacity(0)
            }

            Text("About the Purple Dot")
                .font(.system(size: 18, weight: .bold))

            Text("You'll see a purple dot in your menu bar when SoundPref is active.\n\nThis is Apple's indicator that an app is accessing system audio. It's normal and expected — it appears for all audio capture apps.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()
        }
    }

    private var completionStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.system(size: 20, weight: .bold))

            Text("Click the waveform icon in your menu bar to control app audio.\n\nApps will appear automatically when they produce sound.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()
        }
    }
}
