import AppKit
import Foundation

enum AppResolver {
    static func makeBinding(application: InstalledApplication, keyBinding: KeyBinding, order: Int) -> AppBinding {
        let bookmark = try? application.url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return AppBinding(
            bundleIdentifier: application.bundleIdentifier,
            displayName: application.displayName,
            storedPath: application.url.path,
            bookmarkData: bookmark,
            keyBinding: keyBinding,
            order: order
        )
    }

    static func resolve(
        _ binding: AppBinding,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        bundleLookup: (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    ) -> URL? {
        if let bookmarkData = binding.bookmarkData {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ), fileExists(url.path) {
                return url
            }
        }

        let storedURL = URL(fileURLWithPath: binding.storedPath)
        if fileExists(storedURL.path) {
            return storedURL
        }

        guard !binding.bundleIdentifier.isEmpty else { return nil }
        return bundleLookup(binding.bundleIdentifier)
    }

    static func repairLocation(
        _ binding: AppBinding,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        bundleLookup: (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    ) -> AppBinding {
        guard let resolvedURL = resolve(binding, fileExists: fileExists, bundleLookup: bundleLookup),
              resolvedURL.path != binding.storedPath else {
            return binding
        }
        var repaired = binding
        repaired.storedPath = resolvedURL.path
        repaired.bookmarkData = try? resolvedURL.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return repaired
    }

    static func icon(for binding: AppBinding) -> NSImage {
        if let url = resolve(binding) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
    }
}
