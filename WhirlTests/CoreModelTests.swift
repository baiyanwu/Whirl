import Foundation
import Testing
@testable import Whirl

struct CoreModelTests {
    @Test func keyBindingOnlyAcceptsLettersAndDigits() {
        #expect(KeyBinding.from(keyCode: 0)?.label == "A")
        #expect(KeyBinding.from(keyCode: 18)?.label == "1")
        #expect(KeyBinding.from(keyCode: 49) == nil)
        #expect(KeyBinding.digit(for: 83) == 1)
        #expect(KeyBinding.allowedKeyLabels.count == 36)
        #expect(Set(KeyBinding.allowedKeyLabels.values).count == 36)
    }

    @Test func switchingModifiersAcceptEitherPhysicalKey() {
        #expect(SwitchingModifier.option.accepts(keyCode: 58))
        #expect(SwitchingModifier.option.accepts(keyCode: 61))
        #expect(SwitchingModifier.command.accepts(keyCode: 55))
        #expect(SwitchingModifier.command.accepts(keyCode: 54))
        #expect(SwitchingModifier.shift.accepts(keyCode: 56))
        #expect(SwitchingModifier.shift.accepts(keyCode: 60))
        #expect(SwitchingModifier.control.accepts(keyCode: 59))
        #expect(SwitchingModifier.control.accepts(keyCode: 62))
        #expect(!SwitchingModifier.command.accepts(keyCode: 58))
    }

    @Test func keyBindingDisplayUsesSelectedModifier() throws {
        let binding = try #require(KeyBinding.from(keyCode: 0))
        #expect(binding.displayText(modifier: .option) == "⌥ + A")
        #expect(binding.displayText(modifier: .command) == "⌘ + A")
        #expect(binding.displayText(modifier: .shift) == "⇧ + A")
        #expect(binding.displayText(modifier: .control) == "⌃ + A")
    }

    @Test func standardWindowPolicyExcludesDialogs() {
        let policy = WindowFilterPolicy.standardOnly
        #expect(policy.accepts(role: "AXWindow", subrole: "AXStandardWindow"))
        #expect(!policy.accepts(role: "AXWindow", subrole: "AXDialog"))
        #expect(!policy.accepts(role: "AXButton", subrole: nil))
        #expect(WindowFilterPolicy.allAccessible.accepts(role: "AXWindow", subrole: "AXDialog"))
    }

    @Test func screenWindowVisibilityAcceptsOnlyVisibleApplicationWindows() {
        #expect(ScreenWindowVisibility.isVisibleApplicationWindow(
            layer: 0,
            alpha: 1,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600)
        ))
        #expect(!ScreenWindowVisibility.isVisibleApplicationWindow(
            layer: 1,
            alpha: 1,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600)
        ))
        #expect(!ScreenWindowVisibility.isVisibleApplicationWindow(
            layer: 0,
            alpha: 0,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600)
        ))
        #expect(!ScreenWindowVisibility.isVisibleApplicationWindow(
            layer: 0,
            alpha: 1,
            bounds: .zero
        ))
    }

    @Test func windowPresentationHandlesEmptyTitlesSortingAndMoreThanNineWindows() {
        #expect(!WindowPresentation.title(nil).isEmpty)
        #expect(!WindowPresentation.title("   ").isEmpty)
        #expect(WindowPresentation.title("  Document  ") == "Document")
        #expect(WindowPresentation.precedes(focused: true, title: "Z", focused: false, title: "A"))
        #expect(WindowPresentation.precedes(focused: false, title: "A", focused: false, title: "B"))
        #expect(WindowNumbering.badge(forZeroBasedIndex: 8) == 9)
        #expect(WindowNumbering.badge(forZeroBasedIndex: 9) == nil)
        #expect(WindowNumbering.selectionIndex(forDigit: 9, windowCount: 12) == 8)
        #expect(WindowNumbering.selectionIndex(forDigit: 0, windowCount: 12) == nil)
    }

    @Test func tabPresentationUsesAccessibleLabelsAndRemovesChromeMemorySuffix() {
        #expect(TabPresentation.title("  Documentation  ", description: nil, value: nil) == "Documentation")
        #expect(TabPresentation.title(
            "Whirl - Memory usage 128 MB",
            description: nil,
            value: nil
        ) == "Whirl")
        #expect(TabPresentation.title(nil, description: "Safari Start Page", value: nil) == "Safari Start Page")
        #expect(TabPresentation.title("   ", description: nil, value: nil) == String(localized: "window.untitled_tab"))
        #expect(ApplicationTabAccessibility.isTab(role: "AXRadioButton", subrole: "AXTabButton"))
        #expect(!ApplicationTabAccessibility.isTab(role: "AXRadioButton", subrole: nil))
    }

    @Test func overlayKeyboardUsesConfiguredConfirmationKeyAndReverseTraversal() {
        #expect(OverlayKeyboardMapping.command(
            for: 49,
            flags: [],
            confirmationKey: .space
        ) == .confirm)
        #expect(OverlayKeyboardMapping.command(
            for: 49,
            flags: [],
            confirmationKey: .enter
        ) == nil)
        #expect(OverlayKeyboardMapping.command(
            for: 36,
            flags: [],
            confirmationKey: .enter
        ) == .confirm)
        #expect(OverlayKeyboardMapping.command(
            for: 76,
            flags: [],
            confirmationKey: .enter
        ) == .confirm)
        #expect(OverlayKeyboardMapping.command(
            for: 36,
            flags: [],
            confirmationKey: .space
        ) == nil)
        #expect(OverlayKeyboardMapping.command(
            for: 48,
            flags: [],
            confirmationKey: .enter
        ) == .next)
        #expect(OverlayKeyboardMapping.command(
            for: 48,
            flags: .maskShift,
            confirmationKey: .enter
        ) == .previous)
    }

    @Test func shortcutToggleHidesOnlyWhenTargetIsFrontmostWithAVisibleWindow() {
        #expect(ApplicationTogglePolicy.shouldHide(
            targetProcessIdentifier: 101,
            frontmostProcessIdentifier: 101,
            isTargetHidden: false,
            isTargetActive: false,
            hasVisibleWindow: true
        ))
        #expect(ApplicationTogglePolicy.shouldHide(
            targetProcessIdentifier: 101,
            frontmostProcessIdentifier: 202,
            isTargetHidden: false,
            isTargetActive: true,
            hasVisibleWindow: true
        ))
        #expect(!ApplicationTogglePolicy.shouldHide(
            targetProcessIdentifier: 101,
            frontmostProcessIdentifier: 202,
            isTargetHidden: false,
            isTargetActive: false,
            hasVisibleWindow: true
        ))
        #expect(!ApplicationTogglePolicy.shouldHide(
            targetProcessIdentifier: 101,
            frontmostProcessIdentifier: nil,
            isTargetHidden: false,
            isTargetActive: false,
            hasVisibleWindow: true
        ))
        #expect(!ApplicationTogglePolicy.shouldHide(
            targetProcessIdentifier: 101,
            frontmostProcessIdentifier: 101,
            isTargetHidden: true,
            isTargetActive: true,
            hasVisibleWindow: true
        ))
        #expect(!ApplicationTogglePolicy.shouldHide(
            targetProcessIdentifier: 101,
            frontmostProcessIdentifier: 101,
            isTargetHidden: false,
            isTargetActive: true,
            hasVisibleWindow: false
        ))

    }

    @Test func overlayPlacementCentersAndClamps() {
        let screen = CGRect(x: 0, y: 0, width: 1_000, height: 700)
        let centered = OverlayPlacement.frame(
            contentSize: CGSize(width: 400, height: 100),
            visibleFrame: screen,
            verticalPosition: 0
        )
        #expect(centered.origin.x == 300)
        #expect(centered.origin.y == 300)

        let wide = OverlayPlacement.frame(
            contentSize: CGSize(width: 2_000, height: 100),
            visibleFrame: screen,
            verticalPosition: 1
        )
        #expect(wide.width == 850)
        #expect(wide.maxY == screen.maxY)

        let raised = OverlayPlacement.frame(
            contentSize: CGSize(width: 400, height: 100),
            visibleFrame: screen,
            verticalPosition: 0.4
        )
        #expect(raised.origin.y == 420)

        let bottom = OverlayPlacement.frame(
            contentSize: CGSize(width: 400, height: 100),
            visibleFrame: screen,
            verticalPosition: -1
        )
        #expect(bottom.minY == screen.minY)
    }

    @Test func overlayWidthMatchesCardGeometry() {
        #expect(OverlayLayoutMetrics.contentWidth(
            cardWidth: OverlayLayoutMetrics.applicationCardWidth,
            itemSpacing: OverlayLayoutMetrics.applicationItemSpacing,
            itemCount: 4,
            minimum: 180,
            contentPadding: OverlayLayoutMetrics.applicationContentPadding
        ) == 360)
        #expect(OverlayLayoutMetrics.contentWidth(
            cardWidth: OverlayLayoutMetrics.windowCardWidth,
            itemSpacing: OverlayLayoutMetrics.windowItemSpacing,
            itemCount: 2,
            minimum: 320
        ) == 436)
        #expect(OverlayLayoutMetrics.contentWidth(
            cardWidth: OverlayLayoutMetrics.applicationCardWidth,
            itemSpacing: OverlayLayoutMetrics.applicationItemSpacing,
            itemCount: 1,
            minimum: 180,
            contentPadding: OverlayLayoutMetrics.applicationContentPadding
        ) == 180)
    }

    @Test func windowPickerDisplayDurationDefaultsAndClampsPersistedValues() {
        #expect(AppPreferences.default.windowPickerDisplayDuration == 5)
        #expect(AppPreferences.normalizedWindowPickerDisplayDuration(0) == 1)
        #expect(AppPreferences.normalizedWindowPickerDisplayDuration(3) == 3)
        #expect(AppPreferences.normalizedWindowPickerDisplayDuration(9) == 5)
        #expect(AppPreferences.normalizedWindowPickerDisplayDuration(.infinity) == 5)
        #expect(OverlayDismissalPolicy.messageDelay == 2)
    }

    @Test func overlayVerticalPositionDefaultsAndClampsPersistedValues() {
        #expect(AppPreferences.default.applicationOverlayVerticalPosition == 0)
        #expect(AppPreferences.default.windowOverlayVerticalPosition == 0)
        #expect(AppPreferences.normalizedOverlayVerticalPosition(-2) == -1)
        #expect(AppPreferences.normalizedOverlayVerticalPosition(0.4) == 0.4)
        #expect(AppPreferences.normalizedOverlayVerticalPosition(2) == 1)
        #expect(AppPreferences.normalizedOverlayVerticalPosition(.infinity) == 0)
    }

    @Test func overlayOpacityDefaultsAndClampsPersistedValues() {
        #expect(AppPreferences.default.applicationOverlayOpacity == 1)
        #expect(AppPreferences.default.windowOverlayOpacity == 1)
        #expect(AppPreferences.normalizedOverlayOpacity(0) == 0.3)
        #expect(AppPreferences.normalizedOverlayOpacity(0.65) == 0.65)
        #expect(AppPreferences.normalizedOverlayOpacity(2) == 1)
        #expect(AppPreferences.normalizedOverlayOpacity(.infinity) == 1)
    }

    @Test func persistenceRoundTrip() throws {
        let suiteName = "WhirlTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = PersistenceService(defaults: defaults)
        let binding = AppBinding(
            bundleIdentifier: "com.example.app",
            displayName: "Example",
            storedPath: "/Applications/Example.app",
            bookmarkData: nil,
            keyBinding: try #require(KeyBinding.from(keyCode: 0)),
            order: 0
        )
        service.saveBindings([binding])
        #expect(service.loadBindings() == [binding])

        var preferences = AppPreferences.default
        preferences.switchingModifier = .command
        preferences.longPressDuration = 0.75
        preferences.includeApplicationTabs = true
        preferences.windowPickerDisplayDuration = 4
        preferences.windowConfirmationKey = .space
        preferences.applicationOverlayVerticalPosition = 0.4
        preferences.applicationOverlayOpacity = 0.65
        preferences.windowOverlayVerticalPosition = -0.3
        preferences.windowOverlayOpacity = 0.8
        service.savePreferences(preferences)
        #expect(service.loadPreferences() == preferences)
    }

    @Test func oldPreferencesMigrateAnimationAndDefaultToWindowOnly() throws {
        let data = try #require(#"""
        {
          "optionSide": "left",
          "longPressDuration": 0.4,
          "doubleTapInterval": 0.3,
          "animationDuration": 1.0,
          "overlayVerticalOffset": 0
        }
        """#.data(using: .utf8))
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(preferences.switchingModifier == .option)
        #expect(preferences.windowConfirmationKey == .enter)
        #expect(preferences.animationDuration == AppPreferences.defaultAnimationDuration)
        #expect(!preferences.includeApplicationTabs)
        #expect(preferences.windowPickerDisplayDuration == AppPreferences.defaultWindowPickerDisplayDuration)
        #expect(preferences.applicationOverlayVerticalPosition == AppPreferences.defaultOverlayVerticalPosition)
        #expect(preferences.applicationOverlayOpacity == AppPreferences.defaultOverlayOpacity)
        #expect(preferences.windowOverlayVerticalPosition == AppPreferences.defaultOverlayVerticalPosition)
        #expect(preferences.windowOverlayOpacity == AppPreferences.defaultOverlayOpacity)
    }

    @Test func pointBasedOverlayPositionMigratesToPercentage() throws {
        let data = try #require(#"{ "overlayVerticalOffset": 150 }"#.data(using: .utf8))
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(preferences.applicationOverlayVerticalPosition == 0.5)
        #expect(preferences.windowOverlayVerticalPosition == 0.5)
    }

    @Test func sharedOverlaySettingsMigrateToBothSwitchingModes() throws {
        let data = try #require(
            #"{ "overlayVerticalPosition": -0.4, "overlayOpacity": 0.55 }"#.data(using: .utf8)
        )
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(preferences.applicationOverlayVerticalPosition == -0.4)
        #expect(preferences.windowOverlayVerticalPosition == -0.4)
        #expect(preferences.applicationOverlayOpacity == 0.55)
        #expect(preferences.windowOverlayOpacity == 0.55)
    }

    @Test func installedApplicationNameUsesRequestedLocalization() throws {
        let settingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        let bundle = try #require(Bundle(url: settingsURL))
        let name = InstalledAppScanner.localizedDisplayName(
            for: bundle,
            fallbackURL: settingsURL,
            preferredLanguages: ["zh-Hans-CN"]
        )
        #expect(name == "系统设置")
    }

    @Test func installedApplicationScanIncludesCoreSystemApps() {
        let bundleIdentifiers = Set(InstalledAppScanner.scan().map(\.bundleIdentifier))
        #expect(bundleIdentifiers.contains("com.apple.finder"))
        #expect(bundleIdentifiers.contains("com.apple.systempreferences"))
        #expect(bundleIdentifiers.contains("com.apple.calculator"))
        #expect(bundleIdentifiers.contains("com.apple.AppStore"))
    }

    @Test func bindingValidationAndReordering() throws {
        let suiteName = "WhirlTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = AppModel(
            persistence: PersistenceService(defaults: defaults),
            environment: .uiTesting(applications: [])
        )
        let alpha = InstalledApplication(
            url: URL(fileURLWithPath: "/Applications/Alpha.app"),
            bundleIdentifier: "com.example.alpha",
            displayName: "Alpha"
        )
        let beta = InstalledApplication(
            url: URL(fileURLWithPath: "/Applications/Beta.app"),
            bundleIdentifier: "com.example.beta",
            displayName: "Beta"
        )
        let a = try #require(KeyBinding.from(keyCode: 0))
        let s = try #require(KeyBinding.from(keyCode: 1))

        #expect(model.addBinding(application: alpha, keyBinding: a) == nil)
        #expect(model.addBinding(application: alpha, keyBinding: s) != nil)
        #expect(model.addBinding(application: beta, keyBinding: a) != nil)
        #expect(model.addBinding(application: beta, keyBinding: s) == nil)

        let alphaID = try #require(model.bindings.first(where: { $0.bundleIdentifier == alpha.bundleIdentifier })?.id)
        let betaID = try #require(model.bindings.first(where: { $0.bundleIdentifier == beta.bundleIdentifier })?.id)
        model.moveBinding(draggedID: betaID, onto: alphaID)
        #expect(model.bindings.map(\.bundleIdentifier) == [beta.bundleIdentifier, alpha.bundleIdentifier])
        #expect(model.bindings.map(\.order) == [0, 1])
        model.moveBinding(draggedID: betaID, onto: alphaID)
        #expect(model.bindings.map(\.bundleIdentifier) == [alpha.bundleIdentifier, beta.bundleIdentifier])
        #expect(model.updateKey(for: betaID, to: a) != nil)
    }

    @Test func invalidBookmarkAndMissingPathRelocateByBundleIdentifier() throws {
        let relocatedURL = URL(fileURLWithPath: "/Applications/Relocated.app")
        let binding = AppBinding(
            bundleIdentifier: "com.example.relocated",
            displayName: "Relocated",
            storedPath: "/Applications/Old.app",
            bookmarkData: Data([0x00, 0x01, 0x02]),
            keyBinding: try #require(KeyBinding.from(keyCode: 15)),
            order: 0
        )
        var requestedBundleIdentifier: String?
        let resolved = AppResolver.resolve(
            binding,
            fileExists: { _ in false },
            bundleLookup: {
                requestedBundleIdentifier = $0
                return relocatedURL
            }
        )
        #expect(requestedBundleIdentifier == binding.bundleIdentifier)
        #expect(resolved == relocatedURL)

        let unavailable = AppResolver.resolve(
            binding,
            fileExists: { _ in false },
            bundleLookup: { _ in nil }
        )
        #expect(unavailable == nil)

        let repaired = AppResolver.repairLocation(
            binding,
            fileExists: { $0 == relocatedURL.path },
            bundleLookup: { _ in relocatedURL }
        )
        #expect(repaired.storedPath == relocatedURL.path)
    }

    @Test func accessibilityRequestOpensSettingsAndRefreshesRequiredPermission() throws {
        let suiteName = "WhirlTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var accessibilityGranted = false
        var accessibilityRequests = 0
        var accessibilitySettingsOpens = 0
        let environment = AppEnvironment(
            permissionSnapshot: {
                PermissionSnapshot(accessibilityGranted: accessibilityGranted)
            },
            requestAccessibility: {
                accessibilityRequests += 1
                return false
            },
            openAccessibilitySettings: {
                accessibilitySettingsOpens += 1
                return true
            },
            installedApplications: { [] },
            globalHotKeysEnabled: false
        )
        let model = AppModel(
            persistence: PersistenceService(defaults: defaults),
            environment: environment
        )
        defer { model.stop() }

        model.requestAccessibility()
        #expect(accessibilityRequests == 1)
        #expect(accessibilitySettingsOpens == 1)

        accessibilityGranted = true
        model.verifyPermissions()
        #expect(model.permissions.accessibilityGranted)
        #expect(model.permissions.allGranted)
        #expect(model.permissionNotice == String(localized: "permission.status_ready"))
    }

    @Test func accessibilityIsTheOnlyPermissionRequirement() {
        #expect(!PermissionSnapshot(accessibilityGranted: false).allGranted)
        #expect(PermissionSnapshot(accessibilityGranted: true).allGranted)
    }

    @Test @MainActor func modifierGestureRecognitionDoesNotDependOnAccessibility() {
        let service = GlobalHotKeyService()
        service.update(
            preferences: AppPreferences(
                switchingModifier: .control,
                longPressDuration: 0.4,
                doubleTapInterval: 0.3
            ),
            bindings: [],
            permissions: PermissionSnapshot(accessibilityGranted: false)
        )
        var windowBarRequests = 0
        service.onShowWindowBar = { windowBarRequests += 1 }

        service.handleModifierEvent(keyCode: 59, timestamp: 1.00, isPressed: true)
        service.handleModifierEvent(keyCode: 59, timestamp: 1.05, isPressed: false)
        service.handleModifierEvent(keyCode: 59, timestamp: 1.20, isPressed: true)
        service.handleModifierEvent(keyCode: 59, timestamp: 1.25, isPressed: false)

        #expect(windowBarRequests == 1)
        service.stop()
    }

    @Test @MainActor func modifierEventsUseReportedPressStateInsteadOfEventCount() {
        let service = GlobalHotKeyService()
        service.update(
            preferences: AppPreferences(switchingModifier: .option),
            bindings: [],
            permissions: PermissionSnapshot(accessibilityGranted: false)
        )
        var shortTapRequests = 0
        var windowBarRequests = 0
        service.onShortModifierTap = { shortTapRequests += 1 }
        service.onShowWindowBar = { windowBarRequests += 1 }

        // A release observed without its press must not start a gesture.
        service.handleModifierEvent(keyCode: 58, timestamp: 1.00, isPressed: false)
        // Duplicate monitor delivery must still produce exactly one short tap.
        service.handleModifierEvent(keyCode: 58, timestamp: 1.10, isPressed: true)
        service.handleModifierEvent(keyCode: 58, timestamp: 1.10, isPressed: true)
        service.handleModifierEvent(keyCode: 58, timestamp: 1.15, isPressed: false)
        service.handleModifierEvent(keyCode: 58, timestamp: 1.15, isPressed: false)

        #expect(shortTapRequests == 1)
        #expect(windowBarRequests == 0)
        service.stop()
    }

    @Test func restartApplicationDelegatesToLifecycleCoordinator() throws {
        let suiteName = "WhirlTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = AppModel(
            persistence: PersistenceService(defaults: defaults),
            environment: .uiTesting(applications: [])
        )
        var restartRequested = false
        model.onRestartApplication = { restartRequested = true }

        model.restartApplication()

        #expect(restartRequested)
    }
}
