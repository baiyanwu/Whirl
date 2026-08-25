import AppKit
import SwiftUI

@MainActor
final class PrimaryWindowCoordinator: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var settingsController: NSWindowController?
    private var welcomeController: NSWindowController?

    init(model: AppModel) {
        self.model = model
    }

    func showSettings() {
        if settingsController == nil {
            let view = SettingsRootView(model: model)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1080, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = String(localized: "settings.title")
            window.minSize = NSSize(width: 920, height: 560)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: view)
            settingsController = NSWindowController(window: window)
        }
        show(settingsController)
    }

    func showWelcome() {
        if welcomeController == nil {
            let view = WelcomeView(model: model) { [weak self] in
                self?.welcomeController?.close()
            }
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = String(localized: "welcome.window_title")
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: view)
            welcomeController = NSWindowController(window: window)
        }
        show(welcomeController)
    }

    var hasVisiblePrimaryWindows: Bool {
        settingsController?.window?.isVisible == true || welcomeController?.window?.isVisible == true
    }

    func closeSettings() {
        settingsController?.close()
        DispatchQueue.main.async { [weak self] in self?.updateActivationPolicy() }
    }

    func closePrimaryWindows() {
        settingsController?.close()
        welcomeController?.close()
        DispatchQueue.main.async { [weak self] in self?.updateActivationPolicy() }
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.updateActivationPolicy() }
    }

    private func show(_ controller: NSWindowController?) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        controller?.showWindow(nil)
        controller?.window?.makeKeyAndOrderFront(nil)
    }

    private func updateActivationPolicy() {
        if !hasVisiblePrimaryWindows {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
