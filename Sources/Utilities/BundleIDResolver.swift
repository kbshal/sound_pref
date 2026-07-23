// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import AppKit
import Foundation

/// Resolves app metadata (name, icon) from a bundle identifier or PID.
enum BundleIDResolver {

    /// Resolve the app name and icon from a bundle identifier.
    /// Falls back to the process name from the PID if the bundle can't be found.
    static func resolve(bundleID: String, pid: pid_t) -> (name: String, icon: NSImage?) {
        // Try to find the running application by bundle ID
        if let runningApp = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID
        ).first {
            let name = runningApp.localizedName ?? bundleID
            let icon = runningApp.icon
            return (name, icon)
        }

        // Try to find the app bundle on disk
        if let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) {
            let bundle = Bundle(url: appURL)
            let name = bundle?.infoDictionary?["CFBundleName"] as? String
                ?? bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundleID.components(separatedBy: ".").last
                ?? bundleID
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return (name, icon)
        }

        // Try to get info from the PID directly
        if let runningApp = NSRunningApplication(processIdentifier: pid) {
            let name = runningApp.localizedName ?? bundleID
            let icon = runningApp.icon
            return (name, icon)
        }

        // Final fallback: use the last component of the bundle ID as the name
        let fallbackName = bundleID.components(separatedBy: ".").last ?? bundleID
        return (fallbackName, NSImage(systemSymbolName: "app", accessibilityDescription: fallbackName))
    }

    /// Get just the app name from a bundle identifier.
    static func appName(for bundleID: String) -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let bundle = Bundle(url: appURL)
            return bundle?.infoDictionary?["CFBundleName"] as? String
                ?? bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundleID.components(separatedBy: ".").last
                ?? bundleID
        }
        return bundleID.components(separatedBy: ".").last ?? bundleID
    }

    /// Get the app icon from a bundle identifier.
    static func appIcon(for bundleID: String) -> NSImage? {
        if let runningApp = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID
        ).first {
            return runningApp.icon
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }
}
