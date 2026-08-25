import Foundation

@MainActor
struct AppEnvironment {
    var permissionSnapshot: @MainActor () -> PermissionSnapshot
    var requestAccessibility: @MainActor () -> Bool
    var openAccessibilitySettings: @MainActor () -> Bool
    var installedApplications: @MainActor () -> [InstalledApplication]
    var globalHotKeysEnabled: Bool

    static let live = AppEnvironment(
        permissionSnapshot: PermissionService.snapshot,
        requestAccessibility: PermissionService.requestAccessibility,
        openAccessibilitySettings: PermissionService.openAccessibilitySettings,
        installedApplications: {
            InstalledAppScanner.scan().filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }
        },
        globalHotKeysEnabled: true
    )

    static func uiTesting(
        applications: [InstalledApplication],
        permissions: PermissionSnapshot = PermissionSnapshot(accessibilityGranted: true)
    ) -> AppEnvironment {
        AppEnvironment(
            permissionSnapshot: { permissions },
            requestAccessibility: { true },
            openAccessibilitySettings: { true },
            installedApplications: { applications },
            globalHotKeysEnabled: false
        )
    }
}
