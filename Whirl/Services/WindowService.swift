import AppKit
import ApplicationServices
import Foundation

@MainActor
final class WindowService {
    var filterPolicy: WindowFilterPolicy = .standardOnly

    func hasVisibleWindow(for application: NSRunningApplication) -> Bool {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            CGWindowID(kCGNullWindowID)
        ) as? [[String: Any]] else { return false }

        return windowInfo.contains { item in
            guard let ownerPID = (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  ownerPID == application.processIdentifier,
                  let layer = (item[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  let alpha = (item[kCGWindowAlpha as String] as? NSNumber)?.doubleValue,
                  let rawBounds = item[kCGWindowBounds as String] as? [String: Any],
                  let x = (rawBounds["X"] as? NSNumber)?.doubleValue,
                  let y = (rawBounds["Y"] as? NSNumber)?.doubleValue,
                  let width = (rawBounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (rawBounds["Height"] as? NSNumber)?.doubleValue else { return false }
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            return ScreenWindowVisibility.isVisibleApplicationWindow(
                layer: layer,
                alpha: alpha,
                bounds: bounds
            )
        }
    }

    func windows(
        for application: NSRunningApplication,
        includeApplicationTabs: Bool = false
    ) -> [WindowDescriptor] {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.5)

        guard let elements: [AXUIElement] = attribute(kAXWindowsAttribute, from: appElement) else { return [] }
        let applicationFocusedWindow: AXUIElement? = attribute(
            kAXFocusedWindowAttribute,
            from: appElement
        )
        let applicationMainWindow: AXUIElement? = attribute(
            kAXMainWindowAttribute,
            from: appElement
        )
        let preferredWindow = applicationFocusedWindow ?? applicationMainWindow
        let fallbackIcon = NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        let icon = application.icon ?? fallbackIcon
        let appName = application.localizedName ?? String(localized: "unknown_application")

        let contexts = elements.compactMap { element -> WindowContext? in
            let role: String? = attribute(kAXRoleAttribute, from: element)
            let subrole: String? = attribute(kAXSubroleAttribute, from: element)
            guard filterPolicy.accepts(role: role, subrole: subrole) else { return nil }

            let rawTitle: String? = attribute(kAXTitleAttribute, from: element)
            let focusedByWindowAttribute: Bool = attribute(kAXFocusedAttribute, from: element) ?? false
            let focusedByApplication = preferredWindow.map { CFEqual(element, $0) } ?? false
            let minimized: Bool = attribute(kAXMinimizedAttribute, from: element) ?? false

            return WindowContext(
                title: WindowPresentation.title(rawTitle),
                element: element,
                isFocused: focusedByApplication || focusedByWindowAttribute,
                isMinimized: minimized
            )
        }
        .sorted { lhs, rhs in
            WindowPresentation.precedes(
                focused: lhs.isFocused,
                title: lhs.title,
                focused: rhs.isFocused,
                title: rhs.title
            )
        }

        return contexts.flatMap { context in
            if includeApplicationTabs {
                let tabs = tabDescriptors(
                    in: context,
                    applicationName: appName,
                    applicationIcon: icon,
                    processIdentifier: application.processIdentifier
                )
                if !tabs.isEmpty { return tabs }
            }
            return [windowDescriptor(
                from: context,
                applicationName: appName,
                applicationIcon: icon,
                processIdentifier: application.processIdentifier
            )]
        }
    }

    func activate(_ window: WindowDescriptor) -> Bool {
        if window.isMinimized {
            let result = AXUIElementSetAttributeValue(
                window.windowElement,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
            guard result == .success else { return false }
        }

        guard let app = NSRunningApplication(processIdentifier: window.processIdentifier) else { return false }
        _ = app.activate(options: [.activateAllWindows])
        let raiseResult = AXUIElementPerformAction(window.windowElement, kAXRaiseAction as CFString)
        guard raiseResult == .success else { return false }

        guard let tabElement = window.tabElement else { return true }
        if AXUIElementPerformAction(tabElement, kAXPressAction as CFString) == .success {
            _ = AXUIElementPerformAction(window.windowElement, kAXRaiseAction as CFString)
            return true
        }
        if AXUIElementSetAttributeValue(
            tabElement,
            kAXSelectedAttribute as CFString,
            kCFBooleanTrue
        ) == .success {
            _ = AXUIElementPerformAction(window.windowElement, kAXRaiseAction as CFString)
            return true
        }
        if AXUIElementSetAttributeValue(
            tabElement,
            kAXValueAttribute as CFString,
            kCFBooleanTrue
        ) == .success {
            _ = AXUIElementPerformAction(window.windowElement, kAXRaiseAction as CFString)
            return true
        }
        return false
    }

    private func windowDescriptor(
        from context: WindowContext,
        applicationName: String,
        applicationIcon: NSImage,
        processIdentifier: pid_t
    ) -> WindowDescriptor {
        WindowDescriptor(
            id: UUID(),
            title: context.title,
            applicationName: applicationName,
            applicationIcon: applicationIcon,
            processIdentifier: processIdentifier,
            windowElement: context.element,
            tabElement: nil,
            kind: .window,
            isFocused: context.isFocused,
            isMinimized: context.isMinimized
        )
    }

    private func tabDescriptors(
        in context: WindowContext,
        applicationName: String,
        applicationIcon: NSImage,
        processIdentifier: pid_t
    ) -> [WindowDescriptor] {
        guard let tabs = bestTopLevelTabs(in: context.element), !tabs.isEmpty else { return [] }

        return tabs.map { tab in
            let title: String? = attribute(kAXTitleAttribute, from: tab)
            let description: String? = attribute(kAXDescriptionAttribute, from: tab)
            let value: String? = attribute(kAXValueAttribute, from: tab)
            let selected = booleanAttribute(kAXSelectedAttribute, from: tab)
                ?? booleanAttribute(kAXValueAttribute, from: tab)
                ?? false

            return WindowDescriptor(
                id: UUID(),
                title: TabPresentation.title(title, description: description, value: value),
                applicationName: applicationName,
                applicationIcon: applicationIcon,
                processIdentifier: processIdentifier,
                windowElement: context.element,
                tabElement: tab,
                kind: .tab,
                isFocused: context.isFocused && selected,
                isMinimized: context.isMinimized
            )
        }
    }

    private func bestTopLevelTabs(in window: AXUIElement) -> [AXUIElement]? {
        struct Candidate {
            let tabs: [AXUIElement]
            let depth: Int
            let topDistance: CGFloat
        }

        let windowFrame = frame(of: window)
        var candidates: [Candidate] = []
        var queue: [(element: AXUIElement, depth: Int)] = [(window, 0)]
        var cursor = 0
        var visited = 0

        while cursor < queue.count, visited < 400 {
            let item = queue[cursor]
            cursor += 1
            visited += 1

            let role: String? = attribute(kAXRoleAttribute, from: item.element)
            guard role != "AXWebArea" else { continue }

            if let tabs = tabElements(from: item.element, role: role), !tabs.isEmpty {
                candidates.append(Candidate(
                    tabs: tabs,
                    depth: item.depth,
                    topDistance: topDistance(of: tabs, from: windowFrame)
                ))
            }

            guard item.depth < 8 else { continue }
            let children: [AXUIElement] = attribute(kAXChildrenAttribute, from: item.element) ?? []
            queue.append(contentsOf: children.prefix(80).map { ($0, item.depth + 1) })
        }

        return candidates.sorted { lhs, rhs in
            let lhsNearTop = lhs.topDistance <= 180
            let rhsNearTop = rhs.topDistance <= 180
            if lhsNearTop != rhsNearTop { return lhsNearTop }
            if lhs.depth != rhs.depth { return lhs.depth < rhs.depth }
            return lhs.topDistance < rhs.topDistance
        }.first?.tabs
    }

    private func tabElements(from element: AXUIElement, role: String?) -> [AXUIElement]? {
        if let tabs: [AXUIElement] = attribute(kAXTabsAttribute, from: element), !tabs.isEmpty {
            return tabs
        }
        guard role == (kAXTabGroupRole as String) else { return nil }

        // Chromium exposes browser tabs as AXRadioButton/AXTabButton descendants
        // of AXTabGroup rather than through AXTabs. The extra group level is part
        // of Chromium's native macOS accessibility tree.
        var queue: [(element: AXUIElement, depth: Int)] = [(element, 0)]
        var cursor = 0
        var tabs: [AXUIElement] = []
        while cursor < queue.count {
            let item = queue[cursor]
            cursor += 1

            let itemRole: String? = attribute(kAXRoleAttribute, from: item.element)
            let itemSubrole: String? = attribute(kAXSubroleAttribute, from: item.element)
            if ApplicationTabAccessibility.isTab(role: itemRole, subrole: itemSubrole) {
                tabs.append(item.element)
                continue
            }

            guard item.depth < 3, itemRole != "AXWebArea" else { continue }
            let children: [AXUIElement] = attribute(kAXChildrenAttribute, from: item.element) ?? []
            queue.append(contentsOf: children.prefix(100).map { ($0, item.depth + 1) })
        }
        return tabs.isEmpty ? nil : tabs
    }

    private func topDistance(of tabs: [AXUIElement], from windowFrame: CGRect?) -> CGFloat {
        guard let windowFrame else { return .greatestFiniteMagnitude }
        return tabs.compactMap { frame(of: $0) }
            .map { abs($0.minY - windowFrame.minY) }
            .min() ?? .greatestFiniteMagnitude
    }

    private func booleanAttribute(_ name: String, from element: AXUIElement) -> Bool? {
        if let value: Bool = attribute(name, from: element) { return value }
        if let value: NSNumber = attribute(name, from: element) { return value.boolValue }
        return nil
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute, from: element),
              let size = sizeAttribute(kAXSizeAttribute, from: element) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func pointAttribute(_ name: String, from element: AXUIElement) -> CGPoint? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &rawValue) == .success,
              let rawValue,
              CFGetTypeID(rawValue) == AXValueGetTypeID() else { return nil }
        let value = unsafeDowncast(rawValue, to: AXValue.self)
        var result = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &result) else { return nil }
        return result
    }

    private func sizeAttribute(_ name: String, from element: AXUIElement) -> CGSize? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &rawValue) == .success,
              let rawValue,
              CFGetTypeID(rawValue) == AXValueGetTypeID() else { return nil }
        let value = unsafeDowncast(rawValue, to: AXValue.self)
        var result = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &result) else { return nil }
        return result
    }

    private func attribute<T>(_ name: String, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard result == .success else { return nil }
        return value as? T
    }
}

enum ScreenWindowVisibility {
    static func isVisibleApplicationWindow(layer: Int, alpha: Double, bounds: CGRect) -> Bool {
        layer == 0 && alpha > 0 && bounds.width > 1 && bounds.height > 1
    }
}

@MainActor
private struct WindowContext {
    let title: String
    let element: AXUIElement
    let isFocused: Bool
    let isMinimized: Bool
}
