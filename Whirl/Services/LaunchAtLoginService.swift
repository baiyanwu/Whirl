import ServiceManagement

@MainActor
enum LaunchAtLoginService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled {
                try service.register()
            }
            if service.status == .requiresApproval {
                throw LaunchAtLoginError.requiresApproval
            }
        } else if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case requiresApproval

    var errorDescription: String? {
        String(localized: "error.launch_at_login_requires_approval")
    }
}
