import AppKit
import Combine
import SwiftUI

enum OverlayKind {
    case hidden
    case applications
    case windows
    case message
}

enum OverlayDismissalPolicy {
    static let messageDelay: TimeInterval = 2
}

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var kind: OverlayKind = .hidden
    @Published var applications: [AppBinding] = []
    @Published var windows: [WindowDescriptor] = []
    @Published var switchingModifier = SwitchingModifier.option
    @Published var selectedIndex = 0
    @Published var message = ""
    @Published var backgroundOpacity = AppPreferences.defaultOverlayOpacity

    var onSelectApplication: ((AppBinding) -> Void)?
    var onSelectWindow: ((WindowDescriptor) -> Void)?
    var onOpenSettings: (() -> Void)?
    var windowActivationFailureMessage = ""
}

struct OverlayPlacement {
    static func frame(contentSize: CGSize, visibleFrame: CGRect, verticalPosition: CGFloat) -> CGRect {
        let width = min(contentSize.width, visibleFrame.width * 0.85)
        let height = min(contentSize.height, visibleFrame.height * 0.8)
        let originX = visibleFrame.midX - width / 2
        let clampedPosition = min(max(verticalPosition, -1), 1)
        let progressFromBottom = (clampedPosition + 1) / 2
        let availableTravel = max(0, visibleFrame.height - height)
        let originY = visibleFrame.minY + availableTravel * progressFromBottom
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}

enum OverlayLayoutMetrics {
    static let outerPadding: CGFloat = 10
    static let contentPadding: CGFloat = 16
    static let applicationContentPadding: CGFloat = 8
    static let scrollPadding: CGFloat = 4
    static let applicationItemSpacing: CGFloat = 4
    static let windowItemSpacing: CGFloat = 8
    static let applicationCardWidth: CGFloat = 76
    static let applicationCardHeight: CGFloat = 76
    static let windowCardWidth: CGFloat = 184
    static let windowCardHeight: CGFloat = 76

    static func contentWidth(
        cardWidth: CGFloat,
        itemSpacing: CGFloat,
        itemCount: Int,
        minimum: CGFloat,
        contentPadding: CGFloat = OverlayLayoutMetrics.contentPadding
    ) -> CGFloat {
        guard itemCount > 0 else { return minimum }
        let cardsWidth = CGFloat(itemCount) * cardWidth
        let spacingWidth = CGFloat(itemCount - 1) * itemSpacing
        let horizontalInsets = 2 * (outerPadding + contentPadding + scrollPadding)
        return max(minimum, cardsWidth + spacingWidth + horizontalInsets)
    }
}

@MainActor
final class OverlayPanelController {
    let model = OverlayViewModel()
    private let panel: NSPanel
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var closeWorkItem: DispatchWorkItem?
    private var windowActivationHandler: ((WindowDescriptor) -> Bool)?
    private var windowBarAutoHideDelay = AppPreferences.defaultWindowPickerDisplayDuration

    var isVisible: Bool { panel.isVisible && model.kind != .hidden }
    var isWindowBarVisible: Bool { isVisible && model.kind == .windows }

    init() {
        panel = NonActivatingPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.contentView = NSHostingView(rootView: OverlayRootView(model: model))
        installOutsideClickMonitors()
    }

    func showApplications(
        _ applications: [AppBinding],
        modifier: SwitchingModifier,
        verticalPosition: Double,
        backgroundOpacity: Double,
        onSelect: @escaping (AppBinding) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        closeWorkItem?.cancel()
        model.kind = .applications
        model.applications = applications
        model.switchingModifier = modifier
        model.windows = []
        model.selectedIndex = 0
        model.backgroundOpacity = AppPreferences.normalizedOverlayOpacity(backgroundOpacity)
        model.onSelectApplication = { [weak self] binding in
            self?.hide()
            onSelect(binding)
        }
        model.onOpenSettings = onOpenSettings
        let contentWidth = applications.isEmpty
            ? 390
            : OverlayLayoutMetrics.contentWidth(
                cardWidth: OverlayLayoutMetrics.applicationCardWidth,
                itemSpacing: OverlayLayoutMetrics.applicationItemSpacing,
                itemCount: applications.count,
                minimum: 180,
                contentPadding: OverlayLayoutMetrics.applicationContentPadding
            )
        let contentHeight = applications.isEmpty
            ? 142
            : OverlayLayoutMetrics.applicationCardHeight
                + 2 * (OverlayLayoutMetrics.outerPadding + OverlayLayoutMetrics.applicationContentPadding)
        present(size: CGSize(width: contentWidth, height: contentHeight), verticalPosition: verticalPosition)
    }

    func showWindows(
        _ windows: [WindowDescriptor],
        applicationName: String,
        verticalPosition: Double,
        backgroundOpacity: Double,
        autoHideDelay: TimeInterval,
        activationFailureMessage: String,
        onSelect: @escaping (WindowDescriptor) -> Bool
    ) {
        closeWorkItem?.cancel()
        model.kind = windows.isEmpty ? .message : .windows
        model.applications = []
        model.windows = windows
        model.message = windows.isEmpty
            ? String(format: String(localized: "window.none"), applicationName)
            : ""
        model.selectedIndex = windows.firstIndex(where: \.isFocused) ?? 0
        model.backgroundOpacity = AppPreferences.normalizedOverlayOpacity(backgroundOpacity)
        model.windowActivationFailureMessage = activationFailureMessage
        windowBarAutoHideDelay = AppPreferences.normalizedWindowPickerDisplayDuration(autoHideDelay)
        windowActivationHandler = onSelect
        model.onSelectWindow = { [weak self] window in
            guard let self,
                  let index = self.model.windows.firstIndex(where: { $0.id == window.id }) else { return }
            self.selectWindow(at: index)
        }
        let contentWidth = windows.isEmpty
            ? 390
            : OverlayLayoutMetrics.contentWidth(
                cardWidth: OverlayLayoutMetrics.windowCardWidth,
                itemSpacing: OverlayLayoutMetrics.windowItemSpacing,
                itemCount: windows.count,
                minimum: 320
            )
        let contentHeight = windows.isEmpty
            ? 142
            : OverlayLayoutMetrics.windowCardHeight
                + 2 * (OverlayLayoutMetrics.outerPadding + OverlayLayoutMetrics.contentPadding)
        present(size: CGSize(width: contentWidth, height: contentHeight), verticalPosition: verticalPosition)
        scheduleAutoHide(after: windows.isEmpty
            ? OverlayDismissalPolicy.messageDelay
            : windowBarAutoHideDelay)
    }

    func showMessage(_ message: String, verticalPosition: Double, backgroundOpacity: Double) {
        closeWorkItem?.cancel()
        model.kind = .message
        model.message = message
        model.applications = []
        model.windows = []
        model.backgroundOpacity = AppPreferences.normalizedOverlayOpacity(backgroundOpacity)
        present(size: CGSize(width: 390, height: 112), verticalPosition: verticalPosition)
        scheduleAutoHide(after: OverlayDismissalPolicy.messageDelay)
    }

    func hide() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
        if panel.isVisible {
            panel.orderOut(nil)
        }
        model.kind = .hidden
    }

    func handle(_ command: OverlayKeyboardCommand) -> Bool {
        guard isVisible else { return false }
        if command == .cancel {
            hide()
            return true
        }
        guard model.kind == .windows, !model.windows.isEmpty else { return false }
        scheduleAutoHide(after: windowBarAutoHideDelay)

        switch command {
        case .next:
            model.selectedIndex = (model.selectedIndex + 1) % model.windows.count
        case .previous:
            model.selectedIndex = (model.selectedIndex - 1 + model.windows.count) % model.windows.count
        case .confirm:
            selectWindow(at: model.selectedIndex)
        case .digit(let digit):
            guard let index = WindowNumbering.selectionIndex(
                forDigit: digit,
                windowCount: model.windows.count
            ) else { return true }
            selectWindow(at: index)
        case .cancel:
            break
        }
        return true
    }

    private func selectWindow(at index: Int) {
        guard model.windows.indices.contains(index) else { return }
        let window = model.windows[index]
        if windowActivationHandler?(window) == true {
            hide()
            return
        }

        model.windows.remove(at: index)
        model.selectedIndex = min(index, max(0, model.windows.count - 1))
        model.kind = .message
        model.message = model.windowActivationFailureMessage
        scheduleAutoHide(after: OverlayDismissalPolicy.messageDelay)
    }

    private func scheduleAutoHide(after delay: TimeInterval) {
        closeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.hide() }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func present(size: CGSize, verticalPosition: Double) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        panel.setFrame(
            OverlayPlacement.frame(
                contentSize: size,
                visibleFrame: visibleFrame,
                verticalPosition: verticalPosition
            ),
            display: true
        )
        // The overlay is a high-frequency keyboard surface. Present its final
        // state in one frame so repeated modifier gestures never expose an
        // intermediate mask, scale, or staggered card position.
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.contentView?.displayIfNeeded()
        panel.orderFrontRegardless()
    }

    private func installOutsideClickMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isVisible, !self.panel.frame.contains(NSEvent.mouseLocation) else { return }
                self.hide()
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, self.isVisible, !self.panel.frame.contains(NSEvent.mouseLocation) {
                self.hide()
            }
            return event
        }
    }
}

private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
