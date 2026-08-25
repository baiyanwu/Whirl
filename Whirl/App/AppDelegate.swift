import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var model: AppModel?
    private var windows: PrimaryWindowCoordinator?
    private var explicitTerminationRequested = false
    private var systemTerminationRequested = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = Set(ProcessInfo.processInfo.arguments)
        let isUITesting = arguments.contains("-whirl.ui_testing")
        NSApp.setActivationPolicy(isUITesting ? .regular : .accessory)

        let uiTestApplications = [
            InstalledApplication(
                url: URL(fileURLWithPath: "/Applications/Alpha Notes.app"),
                bundleIdentifier: "com.example.alpha",
                displayName: "Alpha Notes"
            ),
            InstalledApplication(
                url: URL(fileURLWithPath: "/Applications/Beta Browser.app"),
                bundleIdentifier: "com.example.beta",
                displayName: "Beta Browser"
            ),
            InstalledApplication(
                url: URL(fileURLWithPath: "/Applications/Gamma Chat.app"),
                bundleIdentifier: "com.example.gamma",
                displayName: "Gamma Chat"
            )
        ]
        let persistence: PersistenceService
        let environment: AppEnvironment
        if isUITesting, let defaults = UserDefaults(suiteName: "com.baiyanwu.whirl.uitests") {
            defaults.removePersistentDomain(forName: "com.baiyanwu.whirl.uitests")
            persistence = PersistenceService(defaults: defaults)
            let permissions = arguments.contains("-whirl.ui_testing.permissions_denied")
                ? PermissionSnapshot(accessibilityGranted: false)
                : PermissionSnapshot(accessibilityGranted: true)
            environment = .uiTesting(applications: uiTestApplications, permissions: permissions)
            if arguments.contains("-whirl.ui_testing.skip_welcome") {
                persistence.hasCompletedWelcome = true
            }
        } else {
            persistence = PersistenceService()
            environment = .live
        }

        let model = AppModel(persistence: persistence, environment: environment)
        if isUITesting, arguments.contains("-whirl.ui_testing.seed_bindings") {
            model.seedBindingsForUITesting(Array(uiTestApplications.prefix(2)))
        }
        let windows = PrimaryWindowCoordinator(model: model)
        self.model = model
        self.windows = windows
        model.onOpenSettings = { [weak windows] in windows?.showSettings() }
        model.onCloseSettings = { [weak windows] in windows?.closeSettings() }
        model.onRestartApplication = { [weak self] in self?.restartApplication() }
        if !isUITesting {
            model.start()
        }
        setupStatusItem()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillPowerOff),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
        DispatchQueue.main.async { [weak self] in self?.configureMainMenu() }

        if isUITesting, model.hasCompletedWelcome {
            DispatchQueue.main.async { windows.showSettings() }
        } else if !model.hasCompletedWelcome {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                windows.showWelcome()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model?.refreshPermissions()
        model?.refreshLaunchAtLoginStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        model?.stop()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if explicitTerminationRequested || systemTerminationRequested {
            return .terminateNow
        }
        if windows?.hasVisiblePrimaryWindows == true {
            windows?.closePrimaryWindows()
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windows?.showSettings()
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(named: "MenuBarIcon")
                ?? NSImage(systemSymbolName: "wind", accessibilityDescription: "Whirl")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            windows?.showSettings()
        }
    }

    private func showStatusMenu() {
        guard let statusItem else { return }
        model?.refreshPermissions()
        let menu = NSMenu()
        let granted = model?.permissions.allGranted == true
        let permissionTitle = granted
            ? String(localized: "menu.permissions_granted")
            : String(localized: "menu.permissions_required")
        let permissionItem = NSMenuItem(title: permissionTitle, action: nil, keyEquivalent: "")
        permissionItem.isEnabled = false
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "menu.open_settings"), action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: String(localized: "menu.quit_completely"),
            action: #selector(quitCompletely),
            keyEquivalent: "q"
        )
        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        windows?.showSettings()
    }

    @objc private func quitCompletely() {
        explicitTerminationRequested = true
        NSApp.terminate(nil)
    }

    private func restartApplication() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.model?.settingsError = error.localizedDescription
                    return
                }
                self.explicitTerminationRequested = true
                NSApp.terminate(nil)
            }
        }
    }

    @objc private func systemWillPowerOff() {
        systemTerminationRequested = true
    }

    private func configureMainMenu() {
        guard let applicationMenu = NSApp.mainMenu?.items.first?.submenu,
              let quitItem = applicationMenu.items.first(where: { $0.keyEquivalent == "q" }) else { return }
        quitItem.title = String(localized: "menu.close_settings")
    }
}
