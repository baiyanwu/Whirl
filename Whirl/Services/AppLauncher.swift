import AppKit
import Foundation

enum ApplicationTogglePolicy {
    static func shouldHide(
        targetProcessIdentifier: pid_t,
        frontmostProcessIdentifier: pid_t?,
        isTargetHidden: Bool,
        isTargetActive: Bool,
        hasVisibleWindow: Bool
    ) -> Bool {
        hasVisibleWindow
            && !isTargetHidden
            && (isTargetActive || frontmostProcessIdentifier == targetProcessIdentifier)
    }
}

@MainActor
final class AppLauncher {
    private var currentOperationID = UUID()
    private let windowService = WindowService()

    func toggle(_ binding: AppBinding, completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        let operationID = beginOperation()
        if !binding.bundleIdentifier.isEmpty,
           let running = runningApplication(withBundleIdentifier: binding.bundleIdentifier),
           ApplicationTogglePolicy.shouldHide(
               targetProcessIdentifier: running.processIdentifier,
               frontmostProcessIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier,
               isTargetHidden: running.isHidden,
               isTargetActive: running.isActive,
               hasVisibleWindow: windowService.hasVisibleWindow(for: running)
           ) {
            _ = running.hide()
            completion(.success(()))
            return
        }

        launch(binding, operationID: operationID, completion: completion)
    }

    func launch(_ binding: AppBinding, completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        launch(binding, operationID: beginOperation(), completion: completion)
    }

    func reopenWindows(
        for application: NSRunningApplication,
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        let displayName = application.localizedName ?? String(localized: "unknown_application")
        guard let url = application.bundleURL else {
            completion(.failure(LauncherError.activationFailed(displayName)))
            return
        }

        openApplication(
            at: url,
            displayName: displayName,
            operationID: beginOperation(),
            completion: completion
        )
    }

    private func launch(
        _ binding: AppBinding,
        operationID: UUID,
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        let running = binding.bundleIdentifier.isEmpty
            ? nil
            : runningApplication(withBundleIdentifier: binding.bundleIdentifier)
        guard let url = AppResolver.resolve(binding) ?? running?.bundleURL else {
            completion(.failure(LauncherError.applicationMissing(binding.displayName)))
            return
        }

        openApplication(
            at: url,
            displayName: binding.displayName,
            operationID: operationID,
            completion: completion
        )
    }

    private func beginOperation() -> UUID {
        let operationID = UUID()
        currentOperationID = operationID
        return operationID
    }

    private func isCurrent(_ operationID: UUID) -> Bool {
        currentOperationID == operationID
    }

    private func runningApplication(withBundleIdentifier bundleIdentifier: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { !$0.isTerminated })
    }

    private func openApplication(
        at url: URL,
        displayName: String,
        operationID: UUID,
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.hidesOthers = false
        configuration.allowsRunningApplicationSubstitution = true
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] application, error in
            Task { @MainActor in
                guard let self, self.isCurrent(operationID) else { return }
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let application else {
                    completion(.failure(LauncherError.activationFailed(displayName)))
                    return
                }

                // Accessory/background apps cannot become the frontmost regular app. For
                // those, a successful Launch Services open request is the terminal state.
                guard application.activationPolicy == .regular else {
                    completion(.success(()))
                    return
                }

                let becameReady = await self.waitUntilReady(application, attempts: 30)
                guard self.isCurrent(operationID) else { return }
                if becameReady {
                    completion(.success(()))
                } else if self.isFrontmost(application) {
                    completion(.failure(LauncherError.windowOpenFailed(displayName)))
                } else {
                    completion(.failure(LauncherError.activationFailed(displayName)))
                }
            }
        }
    }

    private func waitUntilReady(
        _ application: NSRunningApplication,
        attempts: Int
    ) async -> Bool {
        for attempt in 0..<attempts {
            if isFrontmost(application), windowService.hasVisibleWindow(for: application) {
                return true
            }
            if attempt + 1 < attempts {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        return false
    }

    private func isFrontmost(_ application: NSRunningApplication) -> Bool {
        application.isActive
            || NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
    }

}

enum LauncherError: LocalizedError {
    case applicationMissing(String)
    case activationFailed(String)
    case windowOpenFailed(String)

    var errorDescription: String? {
        switch self {
        case .applicationMissing(let name): String(format: String(localized: "error.app_missing"), name)
        case .activationFailed(let name): String(format: String(localized: "error.activation_failed"), name)
        case .windowOpenFailed(let name): String(format: String(localized: "error.window_open_failed"), name)
        }
    }
}
