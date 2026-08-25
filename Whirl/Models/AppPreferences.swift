import Foundation

enum SwitchingModifier: String, Codable, CaseIterable, Identifiable, Sendable {
    case option
    case command
    case shift
    case control

    var id: String { rawValue }

    func accepts(keyCode: UInt16) -> Bool {
        switch self {
        case .option: keyCode == 58 || keyCode == 61
        case .command: keyCode == 55 || keyCode == 54
        case .shift: keyCode == 56 || keyCode == 60
        case .control: keyCode == 59 || keyCode == 62
        }
    }

    var localizedKey: String {
        switch self {
        case .option: "modifier.option"
        case .command: "modifier.command"
        case .shift: "modifier.shift"
        case .control: "modifier.control"
        }
    }

    var symbol: String {
        switch self {
        case .option: "⌥"
        case .command: "⌘"
        case .shift: "⇧"
        case .control: "⌃"
        }
    }

    var systemImageName: String {
        switch self {
        case .option: "option"
        case .command: "command"
        case .shift: "shift"
        case .control: "control"
        }
    }
}

enum WindowConfirmationKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case enter
    case space

    var id: String { rawValue }

    func accepts(keyCode: UInt16) -> Bool {
        switch self {
        case .space: keyCode == 49
        case .enter: keyCode == 36 || keyCode == 76
        }
    }

    var localizedKey: String {
        switch self {
        case .space: "confirmation_key.space"
        case .enter: "confirmation_key.enter"
        }
    }

    var symbol: String {
        switch self {
        case .space: "␣"
        case .enter: "↩"
        }
    }

    var displayTitle: String {
        switch self {
        case .enter: "↩  Enter"
        case .space: "␣  Space"
        }
    }
}

struct AppPreferences: Codable, Equatable, Sendable {
    static let defaultAnimationDuration = 0.20
    static let defaultWindowPickerDisplayDuration = 5.0
    static let minimumWindowPickerDisplayDuration = 1.0
    static let maximumWindowPickerDisplayDuration = 5.0
    static let defaultOverlayVerticalPosition = 0.0
    static let minimumOverlayVerticalPosition = -1.0
    static let maximumOverlayVerticalPosition = 1.0
    static let defaultOverlayOpacity = 1.0
    static let minimumOverlayOpacity = 0.3
    static let maximumOverlayOpacity = 1.0
    private static let legacyMaximumOverlayVerticalOffset = 300.0

    var switchingModifier: SwitchingModifier = .option
    var longPressDuration: Double = 0.4
    var doubleTapInterval: Double = 0.3
    var animationDuration: Double = Self.defaultAnimationDuration
    var applicationOverlayVerticalPosition: Double = Self.defaultOverlayVerticalPosition
    var applicationOverlayOpacity: Double = Self.defaultOverlayOpacity
    var windowOverlayVerticalPosition: Double = Self.defaultOverlayVerticalPosition
    var windowOverlayOpacity: Double = Self.defaultOverlayOpacity
    var includeApplicationTabs = false
    var windowPickerDisplayDuration: Double = Self.defaultWindowPickerDisplayDuration
    var windowConfirmationKey: WindowConfirmationKey = .enter

    init(
        switchingModifier: SwitchingModifier = .option,
        longPressDuration: Double = 0.4,
        doubleTapInterval: Double = 0.3,
        animationDuration: Double = Self.defaultAnimationDuration,
        applicationOverlayVerticalPosition: Double = Self.defaultOverlayVerticalPosition,
        applicationOverlayOpacity: Double = Self.defaultOverlayOpacity,
        windowOverlayVerticalPosition: Double = Self.defaultOverlayVerticalPosition,
        windowOverlayOpacity: Double = Self.defaultOverlayOpacity,
        includeApplicationTabs: Bool = false,
        windowPickerDisplayDuration: Double = Self.defaultWindowPickerDisplayDuration,
        windowConfirmationKey: WindowConfirmationKey = .enter
    ) {
        self.switchingModifier = switchingModifier
        self.longPressDuration = longPressDuration
        self.doubleTapInterval = doubleTapInterval
        self.animationDuration = animationDuration
        self.applicationOverlayVerticalPosition = Self.normalizedOverlayVerticalPosition(
            applicationOverlayVerticalPosition
        )
        self.applicationOverlayOpacity = Self.normalizedOverlayOpacity(applicationOverlayOpacity)
        self.windowOverlayVerticalPosition = Self.normalizedOverlayVerticalPosition(
            windowOverlayVerticalPosition
        )
        self.windowOverlayOpacity = Self.normalizedOverlayOpacity(windowOverlayOpacity)
        self.includeApplicationTabs = includeApplicationTabs
        self.windowPickerDisplayDuration = Self.normalizedWindowPickerDisplayDuration(windowPickerDisplayDuration)
        self.windowConfirmationKey = windowConfirmationKey
    }

    private enum CodingKeys: String, CodingKey {
        case switchingModifier
        case longPressDuration
        case doubleTapInterval
        case animationDuration
        case applicationOverlayVerticalPosition
        case applicationOverlayOpacity
        case windowOverlayVerticalPosition
        case windowOverlayOpacity
        case includeApplicationTabs
        case windowPickerDisplayDuration
        case windowConfirmationKey
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case overlayVerticalPosition
        case overlayOpacity
        case overlayVerticalOffset
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switchingModifier = try values.decodeIfPresent(
            SwitchingModifier.self,
            forKey: .switchingModifier
        ) ?? .option
        longPressDuration = try values.decodeIfPresent(Double.self, forKey: .longPressDuration) ?? 0.4
        doubleTapInterval = try values.decodeIfPresent(Double.self, forKey: .doubleTapInterval) ?? 0.3
        let storedAnimationDuration = try values.decodeIfPresent(Double.self, forKey: .animationDuration)
            ?? Self.defaultAnimationDuration
        // Animation speed is an internal interaction detail, not a user setting.
        // Clamp older persisted values so upgrades receive the same short entrance.
        animationDuration = min(max(storedAnimationDuration, 0.08), Self.defaultAnimationDuration)
        let legacyValues = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let legacyOverlayVerticalPosition: Double
        if let storedOverlayVerticalPosition = try legacyValues.decodeIfPresent(
            Double.self,
            forKey: .overlayVerticalPosition
        ) {
            legacyOverlayVerticalPosition = Self.normalizedOverlayVerticalPosition(storedOverlayVerticalPosition)
        } else {
            let legacyOffset = try legacyValues.decodeIfPresent(
                Double.self,
                forKey: .overlayVerticalOffset
            ) ?? 0
            legacyOverlayVerticalPosition = Self.normalizedOverlayVerticalPosition(
                legacyOffset / Self.legacyMaximumOverlayVerticalOffset
            )
        }
        let legacyOverlayOpacity = Self.normalizedOverlayOpacity(
            try legacyValues.decodeIfPresent(Double.self, forKey: .overlayOpacity)
                ?? Self.defaultOverlayOpacity
        )
        applicationOverlayVerticalPosition = Self.normalizedOverlayVerticalPosition(
            try values.decodeIfPresent(Double.self, forKey: .applicationOverlayVerticalPosition)
                ?? legacyOverlayVerticalPosition
        )
        applicationOverlayOpacity = Self.normalizedOverlayOpacity(
            try values.decodeIfPresent(Double.self, forKey: .applicationOverlayOpacity)
                ?? legacyOverlayOpacity
        )
        windowOverlayVerticalPosition = Self.normalizedOverlayVerticalPosition(
            try values.decodeIfPresent(Double.self, forKey: .windowOverlayVerticalPosition)
                ?? legacyOverlayVerticalPosition
        )
        windowOverlayOpacity = Self.normalizedOverlayOpacity(
            try values.decodeIfPresent(Double.self, forKey: .windowOverlayOpacity)
                ?? legacyOverlayOpacity
        )
        includeApplicationTabs = try values.decodeIfPresent(Bool.self, forKey: .includeApplicationTabs) ?? false
        let storedWindowPickerDisplayDuration = try values.decodeIfPresent(
            Double.self,
            forKey: .windowPickerDisplayDuration
        ) ?? Self.defaultWindowPickerDisplayDuration
        windowPickerDisplayDuration = Self.normalizedWindowPickerDisplayDuration(
            storedWindowPickerDisplayDuration
        )
        windowConfirmationKey = try values.decodeIfPresent(
            WindowConfirmationKey.self,
            forKey: .windowConfirmationKey
        ) ?? .enter
    }

    static func normalizedWindowPickerDisplayDuration(_ value: Double) -> Double {
        guard value.isFinite else { return defaultWindowPickerDisplayDuration }
        return min(max(value, minimumWindowPickerDisplayDuration), maximumWindowPickerDisplayDuration)
    }

    static func normalizedOverlayVerticalPosition(_ value: Double) -> Double {
        guard value.isFinite else { return defaultOverlayVerticalPosition }
        return min(max(value, minimumOverlayVerticalPosition), maximumOverlayVerticalPosition)
    }

    static func normalizedOverlayOpacity(_ value: Double) -> Double {
        guard value.isFinite else { return defaultOverlayOpacity }
        return min(max(value, minimumOverlayOpacity), maximumOverlayOpacity)
    }

    static let `default` = AppPreferences()
}

struct PermissionSnapshot: Equatable, Sendable {
    var accessibilityGranted: Bool

    var allGranted: Bool { accessibilityGranted }
}
