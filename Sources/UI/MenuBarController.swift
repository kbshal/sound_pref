// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 SoundPref Contributors

import AppKit
import SwiftUI

/// Manages the NSStatusItem (menu bar icon) and NSPopover for the main panel.
///
/// The controller owns the status bar item, handles click events,
/// and presents/dismisses the popover containing `MainPanelView`.
@MainActor
final class MenuBarController: NSObject {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    // Dependencies
    private let deviceManager: AudioDeviceManager
    private let processDiscovery: AudioProcessDiscovery
    private let audioRouter: AudioRouter

    init(
        deviceManager: AudioDeviceManager,
        processDiscovery: AudioProcessDiscovery,
        audioRouter: AudioRouter
    ) {
        self.deviceManager = deviceManager
        self.processDiscovery = processDiscovery
        self.audioRouter = audioRouter
    }

    /// Set up the menu bar item and popover.
    func setup() {
        // Create the status bar item
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "waveform.circle.fill",
                accessibilityDescription: "SoundPref"
            )
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        statusItem = item

        // Create the popover
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 420, height: 620)
        pop.behavior = .transient
        pop.animates = true

        let contentView = MainPanelView(
            deviceManager: deviceManager,
            processDiscovery: processDiscovery,
            audioRouter: audioRouter
        )

        pop.contentViewController = NSHostingController(rootView: contentView)
        popover = pop
    }

    /// Show the onboarding window.
    func showOnboarding() {
        let onboardingView = OnboardingView {
            // On complete: mark onboarding done and dismiss
            SettingsStore.shared.updateGlobalSettings { settings in
                settings.hasCompletedOnboarding = true
            }
            // Close the onboarding window
            NSApp.keyWindow?.close()
        }

        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable]
        window.title = "Welcome to SoundPref"
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Popover Management

    @objc private func togglePopover(_ sender: AnyObject?) {
        if let popover, popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }

        // Refresh data before showing
        processDiscovery.refreshProcesses()
        deviceManager.refreshDevices()

        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Install event monitor to close on click outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover?.performClose(nil)

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    /// Update the menu bar icon based on engine state.
    func updateIcon(isEngineActive: Bool) {
        guard let button = statusItem?.button else { return }

        let symbolName = isEngineActive ? "waveform.circle.fill" : "waveform.circle"
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "SoundPref"
        )
        button.image?.size = NSSize(width: 18, height: 18)
        button.image?.isTemplate = true
    }
}
