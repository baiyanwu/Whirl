import AppKit
import Foundation

enum InstalledAppScanner {
    static func scan() -> [InstalledApplication] {
        let fileManager = FileManager.default
        var roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Network/Applications", isDirectory: true)
        ]
        roots.append(fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true))

        var results: [String: InstalledApplication] = [:]
        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                guard let application = application(at: url) else { continue }
                let key = application.bundleIdentifier.isEmpty
                    ? application.url.standardizedFileURL.path
                    : application.bundleIdentifier
                results[key] = application
            }
        }

        // Finder lives outside every normal Applications directory. Resolve it via
        // Launch Services instead of scanning all of CoreServices, which contains
        // many private agents and setup utilities that should not appear to users.
        let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder")
            ?? URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app", isDirectory: true)
        if let finder = application(at: finderURL) {
            results[finder.bundleIdentifier] = finder
        }

        return results.values.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    static func application(
        at sourceURL: URL,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> InstalledApplication? {
        guard sourceURL.pathExtension.lowercased() == "app" else { return nil }

        let applicationURL = resolvedApplicationURL(sourceURL)
        guard applicationURL.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: applicationURL) else { return nil }

        let name: String
        if applicationURL.standardizedFileURL != sourceURL.standardizedFileURL {
            // Finder aliases are frequently used to expose helper apps under a
            // localized, user-facing name (for example, 豆包浏览器.app). Preserve
            // that label while launching the resolved application bundle.
            name = fileName(for: sourceURL)
        } else {
            name = localizedDisplayName(
                for: bundle,
                fallbackURL: applicationURL,
                preferredLanguages: preferredLanguages
            )
        }

        return InstalledApplication(
            url: applicationURL,
            bundleIdentifier: bundle.bundleIdentifier ?? "",
            displayName: name
        )
    }

    static func localizedDisplayName(
        for bundle: Bundle,
        fallbackURL: URL,
        preferredLanguages: [String]
    ) -> String {
        let localizedInfo = explicitlyLocalizedInfo(
            for: bundle,
            preferredLanguages: preferredLanguages
        )
        let runtimeLocalizedInfo = bundle.localizedInfoDictionary
        let rawInfo = bundle.infoDictionary

        return nonEmptyString(localizedInfo?["CFBundleDisplayName"])
            ?? nonEmptyString(localizedInfo?["CFBundleName"])
            ?? nonEmptyString(runtimeLocalizedInfo?["CFBundleDisplayName"])
            ?? nonEmptyString(runtimeLocalizedInfo?["CFBundleName"])
            ?? nonEmptyString(rawInfo?["CFBundleDisplayName"])
            ?? nonEmptyString(rawInfo?["CFBundleName"])
            ?? fileName(for: fallbackURL)
    }

    private static func resolvedApplicationURL(_ url: URL) -> URL {
        let values = try? url.resourceValues(forKeys: [.isAliasFileKey])
        guard values?.isAliasFile == true else { return url }
        return (try? URL(
            resolvingAliasFileAt: url,
            options: [.withoutUI, .withoutMounting]
        )) ?? url
    }

    private static func explicitlyLocalizedInfo(
        for bundle: Bundle,
        preferredLanguages: [String]
    ) -> [String: Any]? {
        let preferredLocalizations = Bundle.preferredLocalizations(
            from: bundle.localizations,
            forPreferences: preferredLanguages
        )

        if let resourceURL = bundle.resourceURL?.appendingPathComponent("InfoPlist.loctable"),
           let data = try? Data(contentsOf: resourceURL),
           let table = try? PropertyListSerialization.propertyList(from: data, format: nil),
           let localizedTable = table as? [String: [String: Any]] {
            for localization in preferredLocalizations {
                if let info = localizedTable[localization] { return info }
            }
        }

        for localization in preferredLocalizations {
            guard let resourceURL = bundle.url(
                forResource: "InfoPlist",
                withExtension: "strings",
                subdirectory: nil,
                localization: localization
            ),
            let info = NSDictionary(contentsOf: resourceURL) as? [String: Any] else { continue }
            return info
        }
        return nil
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func fileName(for url: URL) -> String {
        let displayName = FileManager.default.displayName(atPath: url.path)
        return (displayName as NSString).deletingPathExtension
    }
}
