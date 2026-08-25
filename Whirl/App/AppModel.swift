import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var preferences: AppPreferences {
        didSet {
            persistence.savePreferences(preferences)
            hotKeyService.update(preferences: preferences, bindings: bindings, permissions: permissions)
        }
    }
    @Published private(set) var bindings: [AppBinding] {
        didSet {
            normalizeBindingOrder()
            persistence.saveBindings(bindings)
            hotKeyService.update(preferences: preferences, bindings: bindings, permissions: permissions)
        }
    }
    @Published private(set) var permissions: PermissionSnapshot
    @Published private(set) var permissionNotice: String?
    @Published var launchAtLoginEnabled = false
    @Published var settingsError: String?

    var onOpenSettings: (() -> Void)?
    var onCloseSettings: (() -> Void)?
    var onRestartApplication: (() -> Void)?

    private let persistence: PersistenceService
    private let environment: AppEnvironment
    private let hotKeyService = GlobalHotKeyService()
    private let launcher = AppLauncher()
    private let windowService = WindowService()
    private let overlayController = OverlayPanelController()
    private var isNormalizingOrder = false
    private var permissionPollingTask: Task<Void, Never>?
    private var permissionPollingChecksRemaining = 0
    private var windowBarTask: Task<Void, Never>?
    private var windowBarRequestID = UUID()

    init(
        persistence: PersistenceService = PersistenceService(),
        environment: AppEnvironment = .live
    ) {
        self.persistence = persistence
        self.environment = environment
        preferences = persistence.loadPreferences()
        bindings = persistence.loadBindings()
        permissions = environment.permissionSnapshot()
        launchAtLoginEnabled = LaunchAtLoginService.isEnabled
    }

    var hasCompletedWelcome: Bool { persistence.hasCompletedWelcome }

    func start() {
        repairBindingLocations()
        hotKeyService.onShowAppBar = { [weak self] in self?.showApplicationBar() }
        hotKeyService.onHideAppBar = { [weak self] in self?.overlayController.hide() }
        hotKeyService.onShowWindowBar = { [weak self] in self?.showWindowBar() }
        hotKeyService.onShortModifierTap = { [weak self] in self?.dismissWindowBarIfVisible() }
        hotKeyService.onLaunchBinding = { [weak self] id in self?.launchBinding(id: id) }
        hotKeyService.onOverlayCommand = { [weak self] command in
            self?.overlayController.handle(command) ?? false
        }
        hotKeyService.onPermissionsUnavailable = { [weak self] in
            self?.refreshPermissions()
        }
        hotKeyService.update(preferences: preferences, bindings: bindings, permissions: permissions)
        refreshPermissions()
    }

    func stop() {
        permissionPollingTask?.cancel()
        permissionPollingTask = nil
        cancelPendingWindowBar()
        hotKeyService.stop()
    }

    func refreshPermissions() {
        permissions = environment.permissionSnapshot()
        guard environment.globalHotKeysEnabled else {
            hotKeyService.stop()
            return
        }
        hotKeyService.update(preferences: preferences, bindings: bindings, permissions: permissions)
        if permissions.allGranted {
            permissionPollingTask?.cancel()
            permissionPollingTask = nil
            permissionNotice = String(localized: "permission.status_ready")
        }
        let eventTapError = String(localized: "error.event_tap_failed")
        if hotKeyService.start() {
            if settingsError == eventTapError { settingsError = nil }
        } else {
            settingsError = eventTapError
        }
    }

    func verifyPermissions() {
        refreshPermissions()
        if permissions.allGranted {
            permissionNotice = String(localized: "permission.status_ready")
        } else {
            permissionNotice = String(localized: "permission.status_not_detected")
            beginPermissionPolling()
        }
    }

    func requestAccessibility() {
        guard !permissions.accessibilityGranted else {
            verifyPermissions()
            return
        }
        _ = environment.requestAccessibility()
        refreshPermissions()
        if !permissions.accessibilityGranted && !environment.openAccessibilitySettings() {
            settingsError = String(localized: "error.open_system_settings_failed")
        } else {
            permissionNotice = String(localized: "permission.status_follow_settings")
        }
        beginPermissionPolling()
    }

    func suspendHotKeys(_ suspended: Bool) {
        hotKeyService.isSuspended = suspended
    }

    func restartApplication() {
        onRestartApplication?()
    }

    func completeWelcome() {
        persistence.hasCompletedWelcome = true
    }

    func addBinding(application: InstalledApplication, keyBinding: KeyBinding) -> String? {
        guard bindings.count < 36 else { return String(localized: "binding.error.limit") }
        if bindings.contains(where: { !$0.bundleIdentifier.isEmpty && $0.bundleIdentifier == application.bundleIdentifier }) {
            return String(localized: "binding.error.duplicate_app")
        }
        if bindings.contains(where: { $0.storedPath == application.url.path }) {
            return String(localized: "binding.error.duplicate_app")
        }
        if bindings.contains(where: { $0.keyBinding.keyCode == keyBinding.keyCode }) {
            return String(localized: "binding.error.duplicate_key")
        }
        bindings.append(AppResolver.makeBinding(application: application, keyBinding: keyBinding, order: bindings.count))
        return nil
    }

    func updateKey(for bindingID: UUID, to keyBinding: KeyBinding) -> String? {
        if bindings.contains(where: { $0.id != bindingID && $0.keyBinding.keyCode == keyBinding.keyCode }) {
            return String(localized: "binding.error.duplicate_key")
        }
        guard let index = bindings.firstIndex(where: { $0.id == bindingID }) else { return nil }
        bindings[index].keyBinding = keyBinding
        return nil
    }

    func removeBinding(id: UUID) {
        bindings.removeAll { $0.id == id }
    }

    func moveBinding(draggedID: UUID, onto targetID: UUID) {
        guard draggedID != targetID,
              let source = bindings.firstIndex(where: { $0.id == draggedID }),
              let target = bindings.firstIndex(where: { $0.id == targetID }) else { return }
        let item = bindings.remove(at: source)
        let destination = min(max(0, target), bindings.count)
        bindings.insert(item, at: destination)
    }

    func bindingAvailability(_ binding: AppBinding) -> Bool {
        AppResolver.resolve(binding) != nil
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            launchAtLoginEnabled = LaunchAtLoginService.isEnabled
            settingsError = nil
        } catch {
            launchAtLoginEnabled = LaunchAtLoginService.isEnabled
            settingsError = error.localizedDescription
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = LaunchAtLoginService.isEnabled
    }

    func scanInstalledApplications() -> [InstalledApplication] {
        environment.installedApplications()
    }

    func seedBindingsForUITesting(_ applications: [InstalledApplication]) {
        for (application, keyCode) in zip(applications, [UInt16(0), UInt16(1)]) {
            guard let binding = KeyBinding.from(keyCode: keyCode) else { continue }
            _ = addBinding(application: application, keyBinding: binding)
        }
    }

    func applicationFromURL(_ url: URL) -> InstalledApplication? {
        InstalledAppScanner.application(at: url)
    }

    func launchBinding(id: UUID) {
        guard let binding = bindings.first(where: { $0.id == id }) else { return }
        toggle(binding)
    }

    func launch(_ binding: AppBinding) {
        cancelPendingWindowBar()
        overlayController.hide()
        launcher.launch(binding) { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result {
                self.overlayController.showMessage(
                    error.localizedDescription,
                    verticalPosition: self.preferences.applicationOverlayVerticalPosition,
                    backgroundOpacity: self.preferences.applicationOverlayOpacity
                )
            }
        }
    }

    private func toggle(_ binding: AppBinding) {
        cancelPendingWindowBar()
        overlayController.hide()
        launcher.toggle(binding) { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result {
                self.overlayController.showMessage(
                    error.localizedDescription,
                    verticalPosition: self.preferences.applicationOverlayVerticalPosition,
                    backgroundOpacity: self.preferences.applicationOverlayOpacity
                )
            }
        }
    }

    private func showApplicationBar() {
        cancelPendingWindowBar()
        overlayController.showApplications(
            bindings,
            modifier: preferences.switchingModifier,
            verticalPosition: preferences.applicationOverlayVerticalPosition,
            backgroundOpacity: preferences.applicationOverlayOpacity,
            onSelect: { [weak self] binding in self?.launch(binding) },
            onOpenSettings: { [weak self] in
                self?.overlayController.hide()
                self?.onOpenSettings?()
            }
        )
    }

    private func showWindowBar() {
        cancelPendingWindowBar()
        let requestID = UUID()
        windowBarRequestID = requestID

        guard permissions.accessibilityGranted else {
            overlayController.showMessage(
                String(localized: "permission.window_selection_required"),
                verticalPosition: preferences.windowOverlayVerticalPosition,
                backgroundOpacity: preferences.windowOverlayOpacity
            )
            return
        }

        guard let application = NSWorkspace.shared.frontmostApplication else {
            overlayController.showMessage(
                String(localized: "window.no_frontmost_app"),
                verticalPosition: preferences.windowOverlayVerticalPosition,
                backgroundOpacity: preferences.windowOverlayOpacity
            )
            return
        }

        let existingWindows = windowService.windows(
            for: application,
            includeApplicationTabs: preferences.includeApplicationTabs
        )
        guard existingWindows.isEmpty else {
            presentWindowBar(existingWindows, for: application)
            return
        }

        // A running app can own the menu bar even after its last window was
        // closed. Match a Dock click by asking it to reopen, then wait for its
        // accessibility window tree before presenting the picker.
        overlayController.hide()
        launcher.reopenWindows(for: application) { [weak self] result in
            guard let self, self.windowBarRequestID == requestID else { return }
            switch result {
            case .failure(let error):
                self.overlayController.showMessage(
                    error.localizedDescription,
                    verticalPosition: self.preferences.windowOverlayVerticalPosition,
                    backgroundOpacity: self.preferences.windowOverlayOpacity
                )
            case .success:
                self.waitForReopenedWindows(for: application, requestID: requestID)
            }
        }
    }

    private func dismissWindowBarIfVisible() {
        guard overlayController.isWindowBarVisible else { return }
        cancelPendingWindowBar()
        overlayController.hide()
    }

    private func waitForReopenedWindows(for application: NSRunningApplication, requestID: UUID) {
        let includeApplicationTabs = preferences.includeApplicationTabs
        windowBarTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for attempt in 0..<30 {
                guard !Task.isCancelled, self.windowBarRequestID == requestID else { return }
                let windows = self.windowService.windows(
                    for: application,
                    includeApplicationTabs: includeApplicationTabs
                )
                if !windows.isEmpty {
                    self.windowBarTask = nil
                    self.presentWindowBar(windows, for: application)
                    return
                }
                if attempt + 1 < 30 {
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }

            guard !Task.isCancelled, self.windowBarRequestID == requestID else { return }
            self.windowBarTask = nil
            self.overlayController.showMessage(
                LauncherError.windowOpenFailed(
                    application.localizedName ?? String(localized: "unknown_application")
                ).localizedDescription,
                verticalPosition: self.preferences.windowOverlayVerticalPosition,
                backgroundOpacity: self.preferences.windowOverlayOpacity
            )
        }
    }

    private func presentWindowBar(_ windows: [WindowDescriptor], for application: NSRunningApplication) {
        overlayController.showWindows(
            windows,
            applicationName: application.localizedName ?? String(localized: "unknown_application"),
            verticalPosition: preferences.windowOverlayVerticalPosition,
            backgroundOpacity: preferences.windowOverlayOpacity,
            autoHideDelay: preferences.windowPickerDisplayDuration,
            activationFailureMessage: String(localized: "window.activation_failed")
        ) { [weak self] window in
            guard let self else { return false }
            return self.windowService.activate(window)
        }
    }

    private func cancelPendingWindowBar() {
        windowBarRequestID = UUID()
        windowBarTask?.cancel()
        windowBarTask = nil
    }

    private func normalizeBindingOrder() {
        guard !isNormalizingOrder else { return }
        let normalized = bindings.enumerated().map { offset, item -> AppBinding in
            var copy = item
            copy.order = offset
            return copy
        }
        guard normalized != bindings else { return }
        isNormalizingOrder = true
        bindings = normalized
        isNormalizingOrder = false
    }

    private func repairBindingLocations() {
        let repaired = bindings.map { AppResolver.repairLocation($0) }
        if repaired != bindings {
            bindings = repaired
        }
    }

    private func beginPermissionPolling() {
        permissionPollingChecksRemaining = 120
        guard permissionPollingTask == nil else { return }

        permissionPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { break }
                self.refreshPermissions()
                self.permissionPollingChecksRemaining -= 1
                if self.permissions.allGranted || self.permissionPollingChecksRemaining <= 0 {
                    break
                }
            }
            self?.permissionPollingTask = nil
        }
    }
}
