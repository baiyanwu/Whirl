import AppKit
@preconcurrency import ApplicationServices

enum PermissionService {
    static func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(accessibilityGranted: AXIsProcessTrusted())
    }

    @discardableResult
    static func requestAccessibility() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    static func openAccessibilitySettings() -> Bool {
        openSystemSettings(anchor: "Privacy_Accessibility")
    }

    private static func openSystemSettings(anchor: String) -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return false
        }
        if NSWorkspace.shared.open(url) {
            return true
        }
        guard let fallbackURL = URL(string: "x-apple.systempreferences:com.apple.preference.security") else {
            return false
        }
        return NSWorkspace.shared.open(fallbackURL)
    }
}
