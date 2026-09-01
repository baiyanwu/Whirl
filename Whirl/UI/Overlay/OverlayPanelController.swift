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
    @Published var layoutStyle = OverlayLayoutStyle.horizontal
    @Published var fanRevealedItemCount = 0
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
    static let applicationIconSize: CGFloat = 48
    static let applicationFanIconSize: CGFloat = 40
    static let applicationFanShortcutFontSize: CGFloat = 10
    static let windowCardWidth: CGFloat = 184
    static let windowCardHeight: CGFloat = 76
    static let windowIconSize: CGFloat = 36
    static let windowFanIconSize: CGFloat = 32
    static let windowCardHorizontalPadding: CGFloat = 12
    static let fanCardCornerRadius: CGFloat = 20
    static let fanSideInset: CGFloat = 24
    static let fanTopInset: CGFloat = 16
    static let fanBottomInset: CGFloat = 16
    static let applicationFanStep: CGFloat = 52
    static let applicationFanMaximumRotation = 44.0
    static let windowFanStep: CGFloat = 104
    static let windowFanMaximumRotation = 28.0
    static let fanRevealItemDuration = 0.12

    static func applicationShortcutText(
        for keyBinding: KeyBinding,
        modifier: SwitchingModifier,
        layoutStyle: OverlayLayoutStyle
    ) -> String {
        switch layoutStyle {
        case .horizontal:
            return keyBinding.displayText(modifier: modifier)
        case .fan:
            return keyBinding.label
        }
    }

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

    static func applicationContentSize(itemCount: Int, layoutStyle: OverlayLayoutStyle) -> CGSize {
        switch layoutStyle {
        case .horizontal:
            return CGSize(
                width: contentWidth(
                    cardWidth: applicationCardWidth,
                    itemSpacing: applicationItemSpacing,
                    itemCount: itemCount,
                    minimum: 180,
                    contentPadding: applicationContentPadding
                ),
                height: applicationCardHeight + 2 * (outerPadding + applicationContentPadding)
            )
        case .fan:
            let geometry = applicationFanGeometry(itemCount: itemCount)
            return CGSize(
                width: max(
                    180,
                    geometry.contentSize.width
                        + 2 * (outerPadding + applicationContentPadding + scrollPadding)
                ),
                height: geometry.contentSize.height
                    + 2 * (outerPadding + applicationContentPadding)
            )
        }
    }

    static func windowContentSize(itemCount: Int, layoutStyle: OverlayLayoutStyle) -> CGSize {
        switch layoutStyle {
        case .horizontal:
            return CGSize(
                width: contentWidth(
                    cardWidth: windowCardWidth,
                    itemSpacing: windowItemSpacing,
                    itemCount: itemCount,
                    minimum: 320
                ),
                height: windowCardHeight + 2 * (outerPadding + contentPadding)
            )
        case .fan:
            let geometry = windowFanGeometry(itemCount: itemCount)
            return CGSize(
                width: max(
                    320,
                    geometry.contentSize.width + 2 * (outerPadding + contentPadding + scrollPadding)
                ),
                height: geometry.contentSize.height + 2 * (outerPadding + contentPadding)
            )
        }
    }

    static func applicationFanGeometry(itemCount: Int) -> OverlayFanGeometry {
        OverlayFanGeometry(
            itemCount: itemCount,
            cardSize: CGSize(width: applicationCardWidth, height: applicationCardHeight),
            horizontalStep: applicationFanStep,
            maximumRotation: applicationFanMaximumRotation,
            sideInset: fanSideInset,
            topInset: fanTopInset,
            bottomInset: fanBottomInset
        )
    }

    static func windowFanGeometry(itemCount: Int) -> OverlayFanGeometry {
        OverlayFanGeometry(
            itemCount: itemCount,
            cardSize: CGSize(width: windowCardWidth, height: windowCardHeight),
            horizontalStep: windowFanStep,
            maximumRotation: windowFanMaximumRotation,
            sideInset: fanSideInset,
            topInset: fanTopInset,
            bottomInset: fanBottomInset
        )
    }
}

struct OverlayFanItemTransform: Equatable {
    let offset: CGSize
    let rotationDegrees: Double
    let zIndex: Double
}

struct OverlayFanGeometry: Equatable {
    let itemCount: Int
    let cardSize: CGSize
    let horizontalStep: CGFloat
    let maximumRotation: Double
    let sideInset: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat

    var radius: CGFloat {
        guard itemCount > 1 else { return 0 }
        let maximumRotationRadians = CGFloat(maximumRotation * .pi / 180)
        guard maximumRotationRadians > 0 else { return 0 }
        let targetCenterSpan = CGFloat(itemCount - 1) * horizontalStep
        return targetCenterSpan / (2 * sin(maximumRotationRadians))
    }

    var rotationAnchor: UnitPoint {
        guard cardSize.height > 0 else { return .center }
        return UnitPoint(
            x: 0.5,
            y: (cardSize.height / 2 + radius) / cardSize.height
        )
    }

    private var rawContentBounds: CGRect {
        let indices = itemCount > 0 ? 0..<itemCount : 0..<1
        return indices.reduce(into: CGRect.null) { bounds, index in
            bounds = bounds.union(rawFrame(at: index))
        }
    }

    var baseOffset: CGSize {
        CGSize(
            width: sideInset - rawContentBounds.minX,
            height: topInset - rawContentBounds.minY
        )
    }

    var contentSize: CGSize {
        return CGSize(
            width: rawContentBounds.width + 2 * sideInset,
            height: rawContentBounds.height + topInset + bottomInset
        )
    }

    var commonPivotOffset: CGPoint {
        CGPoint(
            x: baseOffset.width + cardSize.width / 2,
            y: baseOffset.height + cardSize.height / 2 + radius
        )
    }

    var revealOriginRotationDegrees: Double {
        transform(at: 0).rotationDegrees
    }

    func transform(at index: Int) -> OverlayFanItemTransform {
        guard itemCount > 1 else {
            return OverlayFanItemTransform(
                offset: baseOffset,
                rotationDegrees: 0,
                zIndex: 1
            )
        }

        let clampedIndex = min(max(index, 0), itemCount - 1)

        return OverlayFanItemTransform(
            offset: baseOffset,
            rotationDegrees: rotationDegrees(at: clampedIndex),
            zIndex: Double(clampedIndex + 1)
        )
    }

    func itemCenter(at index: Int) -> CGPoint {
        let angle = rotationDegrees(at: index) * .pi / 180
        return CGPoint(
            x: commonPivotOffset.x + radius * CGFloat(sin(angle)),
            y: commonPivotOffset.y - radius * CGFloat(cos(angle))
        )
    }

    private func rawFrame(at index: Int) -> CGRect {
        let angle = rotationDegrees(at: index) * .pi / 180
        let cosine = CGFloat(cos(angle))
        let sine = CGFloat(sin(angle))
        let center = CGPoint(
            x: cardSize.width / 2 + radius * sine,
            y: cardSize.height / 2 + radius * (1 - cosine)
        )
        let halfWidth = abs(cosine) * cardSize.width / 2
            + abs(sine) * cardSize.height / 2
        let halfHeight = abs(sine) * cardSize.width / 2
            + abs(cosine) * cardSize.height / 2
        return CGRect(
            x: center.x - halfWidth,
            y: center.y - halfHeight,
            width: 2 * halfWidth,
            height: 2 * halfHeight
        )
    }

    private func rotationDegrees(at index: Int) -> Double {
        guard itemCount > 1 else { return 0 }
        let clampedIndex = min(max(index, 0), itemCount - 1)
        let normalizedPosition = (2 * CGFloat(clampedIndex) / CGFloat(itemCount - 1)) - 1
        return Double(normalizedPosition) * maximumRotation
    }
}

@MainActor
final class OverlayPanelController {
    let model = OverlayViewModel()
    private let panel: NSPanel
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var closeWorkItem: DispatchWorkItem?
    private var fanRevealTask: Task<Void, Never>?
    private var fanRevealGeneration = UUID()
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
        layoutStyle: OverlayLayoutStyle,
        verticalPosition: Double,
        backgroundOpacity: Double,
        onSelect: @escaping (AppBinding) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        closeWorkItem?.cancel()
        model.kind = .applications
        model.applications = applications
        model.switchingModifier = modifier
        model.layoutStyle = layoutStyle
        model.windows = []
        model.selectedIndex = 0
        prepareFanReveal(itemCount: applications.count, layoutStyle: layoutStyle)
        model.backgroundOpacity = AppPreferences.normalizedOverlayOpacity(backgroundOpacity)
        model.onSelectApplication = { [weak self] binding in
            self?.hide()
            onSelect(binding)
        }
        model.onOpenSettings = onOpenSettings
        let contentSize = applications.isEmpty
            ? CGSize(width: 390, height: 142)
            : OverlayLayoutMetrics.applicationContentSize(
                itemCount: applications.count,
                layoutStyle: layoutStyle
            )
        present(size: contentSize, verticalPosition: verticalPosition)
        startFanRevealIfNeeded(itemCount: applications.count, layoutStyle: layoutStyle)
    }

    func showWindows(
        _ windows: [WindowDescriptor],
        applicationName: String,
        layoutStyle: OverlayLayoutStyle,
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
        model.layoutStyle = layoutStyle
        prepareFanReveal(itemCount: windows.count, layoutStyle: layoutStyle)
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
        let contentSize = windows.isEmpty
            ? CGSize(width: 390, height: 142)
            : OverlayLayoutMetrics.windowContentSize(
                itemCount: windows.count,
                layoutStyle: layoutStyle
            )
        present(size: contentSize, verticalPosition: verticalPosition)
        startFanRevealIfNeeded(itemCount: windows.count, layoutStyle: layoutStyle)
        scheduleAutoHide(after: windows.isEmpty
            ? OverlayDismissalPolicy.messageDelay
            : windowBarAutoHideDelay)
    }

    func showMessage(_ message: String, verticalPosition: Double, backgroundOpacity: Double) {
        closeWorkItem?.cancel()
        cancelFanReveal()
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
        cancelFanReveal()
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
        cancelFanReveal()
        model.kind = .message
        model.message = model.windowActivationFailureMessage
        scheduleAutoHide(after: OverlayDismissalPolicy.messageDelay)
    }

    private func prepareFanReveal(itemCount: Int, layoutStyle: OverlayLayoutStyle) {
        cancelFanReveal()
        let shouldAnimate = layoutStyle == .fan
            && itemCount > 0
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        model.fanRevealedItemCount = shouldAnimate ? 0 : itemCount
    }

    private func startFanRevealIfNeeded(itemCount: Int, layoutStyle: OverlayLayoutStyle) {
        guard layoutStyle == .fan,
              itemCount > 0,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }

        let generation = fanRevealGeneration
        fanRevealTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            defer {
                if self.fanRevealGeneration == generation {
                    self.fanRevealTask = nil
                }
            }

            guard !Task.isCancelled, self.fanRevealGeneration == generation else { return }
            withAnimation(
                .timingCurve(
                    0.16,
                    1,
                    0.3,
                    1,
                    duration: OverlayLayoutMetrics.fanRevealItemDuration
                )
            ) {
                self.model.fanRevealedItemCount = itemCount
            }
        }
    }

    private func cancelFanReveal() {
        fanRevealTask?.cancel()
        fanRevealTask = nil
        fanRevealGeneration = UUID()
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
        if panel.isVisible {
            panel.orderOut(nil)
        }
        panel.setFrame(
            OverlayPlacement.frame(
                contentSize: size,
                visibleFrame: visibleFrame,
                verticalPosition: verticalPosition
            ),
            display: true
        )
        // Flush the freshly reset reveal state before ordering the reused panel
        // front. This prevents a previous presentation's fully revealed frame
        // from flashing before the new simultaneous reveal begins.
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
