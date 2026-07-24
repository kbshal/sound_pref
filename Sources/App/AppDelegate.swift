// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import AppKit
import os.log

private let logger = Logger(subsystem: "com.soundpref", category: "AppDelegate")

/// Application delegate that initializes all subsystems and manages the app lifecycle.
///
/// SoundPref is an LSUIElement (no dock icon) — all interaction
/// happens through the menu bar icon and its popover panel.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Subsystems

    /// Manages system audio devices.
    private var deviceManager: AudioDeviceManager!

    /// Discovers running audio-producing processes.
    private var processDiscovery: AudioProcessDiscovery!

    /// Orchestrates per-app audio taps and routing.
    private var audioRouter: AudioRouter!

    /// Controls the menu bar icon and popover.
    private var menuBarController: MenuBarController!

    /// Settings store.
    private var settingsStore: SettingsStore { SettingsStore.shared }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("SoundPref starting up...")

        // Initialize subsystems in dependency order
        deviceManager = AudioDeviceManager()
        processDiscovery = AudioProcessDiscovery()
        audioRouter = AudioRouter(
            processDiscovery: processDiscovery,
            deviceManager: deviceManager
        )

        // Set up the menu bar
        menuBarController = MenuBarController(
            deviceManager: deviceManager,
            processDiscovery: processDiscovery,
            audioRouter: audioRouter
        )
        menuBarController.setup()

        // Show onboarding if first launch
        if !settingsStore.globalSettings.hasCompletedOnboarding {
            menuBarController.showOnboarding()
        }

        logger.info("SoundPref ready. Found \(self.deviceManager.outputDevices.count) output devices, \(self.processDiscovery.activeApps.count) active audio apps.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("SoundPref shutting down...")

        // Stop all audio taps — this restores normal system audio
        audioRouter?.stopAllTaps()

        logger.info("All taps stopped. Goodbye!")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
