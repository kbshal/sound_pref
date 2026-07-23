// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import AppKit
import SwiftUI

/// Manages the NSStatusItem (menu bar icon) and NSPopover for the main panel.
///
/// The controller owns the status bar item, handles click events,
/// and presents/dismisses the popover containing `MainPanelView`.
@MainActor
final class MenuBarController {

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
                accessibilityDescription: "OpenSoundSource"
            )
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        statusItem = item

        // Create the popover
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 340, height: 480)
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
        window.title = "Welcome to OpenSoundSource"
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
            accessibilityDescription: "OpenSoundSource"
        )
        button.image?.size = NSSize(width: 18, height: 18)
        button.image?.isTemplate = true
    }
}

// Required for @objc selector on @MainActor class
extension MenuBarController: NSObjectProtocol {
    nonisolated func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? MenuBarController else { return false }
        return self === other
    }

    nonisolated var hash: Int { ObjectIdentifier(self).hashValue }
    nonisolated var superclass: AnyClass? { nil }
    nonisolated var description: String { "MenuBarController" }
    nonisolated var debugDescription: String { "MenuBarController" }

    nonisolated func `self`() -> Self { self }
    nonisolated func perform(_ aSelector: Selector!) -> Unmanaged<AnyObject>! { nil }
    nonisolated func perform(_ aSelector: Selector!, with object: Any!) -> Unmanaged<AnyObject>! { nil }
    nonisolated func perform(_ aSelector: Selector!, with object1: Any!, with object2: Any!) -> Unmanaged<AnyObject>! { nil }
    nonisolated func isProxy() -> Bool { false }
    nonisolated func isKind(of aClass: AnyClass) -> Bool { false }
    nonisolated func isMember(of aClass: AnyClass) -> Bool { false }
    nonisolated func conforms(to aProtocol: Protocol) -> Bool { false }
    nonisolated func responds(to aSelector: Selector!) -> Bool {
        aSelector == #selector(togglePopover(_:))
    }
}
