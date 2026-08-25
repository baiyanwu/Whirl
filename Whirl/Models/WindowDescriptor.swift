import AppKit
import ApplicationServices
import Foundation

enum WindowFilterPolicy: String, Codable, Sendable {
    case standardOnly
    case allAccessible

    func accepts(role: String?, subrole: String?) -> Bool {
        switch self {
        case .standardOnly:
            return role == (kAXWindowRole as String) && subrole == (kAXStandardWindowSubrole as String)
        case .allAccessible:
            return role == (kAXWindowRole as String)
        }
    }
}

enum WindowPresentation {
    static func title(_ rawTitle: String?) -> String {
        let trimmed = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false ? trimmed : nil) ?? String(localized: "window.untitled")
    }

    static func precedes(
        focused lhsFocused: Bool,
        title lhsTitle: String,
        focused rhsFocused: Bool,
        title rhsTitle: String
    ) -> Bool {
        if lhsFocused != rhsFocused { return lhsFocused }
        return lhsTitle.localizedStandardCompare(rhsTitle) == .orderedAscending
    }
}

enum TabPresentation {
    static func title(_ title: String?, description: String?, value: String?) -> String {
        let candidates = [title, description, value]
        for candidate in candidates {
            guard var text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                continue
            }
            text = text.replacingOccurrences(
                of: #"\s+-\s+(Memory usage|内存用量).*$"#,
                with: "",
                options: .regularExpression
            )
            if !text.isEmpty { return text }
        }
        return String(localized: "window.untitled_tab")
    }
}

enum ApplicationTabAccessibility {
    static func isTab(role: String?, subrole: String?) -> Bool {
        role == NSAccessibility.Role.radioButton.rawValue
            && subrole == "AXTabButton"
    }
}

enum WindowNumbering {
    static func badge(forZeroBasedIndex index: Int) -> Int? {
        let number = index + 1
        return (1 ... 9).contains(number) ? number : nil
    }

    static func selectionIndex(forDigit digit: Int, windowCount: Int) -> Int? {
        guard (1 ... 9).contains(digit), digit <= windowCount else { return nil }
        return digit - 1
    }
}

enum WindowTargetKind: Equatable, Sendable {
    case window
    case tab
}

@MainActor
struct WindowDescriptor: Identifiable {
    let id: UUID
    let title: String
    let applicationName: String
    let applicationIcon: NSImage
    let processIdentifier: pid_t
    let windowElement: AXUIElement
    let tabElement: AXUIElement?
    let kind: WindowTargetKind
    let isFocused: Bool
    let isMinimized: Bool
}

@MainActor
protocol WindowPreviewProvider {
    func preview(for window: WindowDescriptor) async -> NSImage?
}

@MainActor
struct EmptyWindowPreviewProvider: WindowPreviewProvider {
    func preview(for window: WindowDescriptor) async -> NSImage? { nil }
}
