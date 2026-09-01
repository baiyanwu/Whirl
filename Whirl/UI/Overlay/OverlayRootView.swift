import AppKit
import SwiftUI

struct OverlayRootView: View {
    @ObservedObject var model: OverlayViewModel

    var body: some View {
        ZStack {
            if usesContainerBackground {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(model.backgroundOpacity)
                    .allowsHitTesting(false)
            }

            Group {
                switch model.kind {
                case .applications:
                    applicationContent
                case .windows:
                    windowContent
                case .message:
                    messageContent
                case .hidden:
                    EmptyView()
                }
            }
            .padding(activeContentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(OverlayLayoutMetrics.outerPadding)
    }

    private var usesContainerBackground: Bool {
        guard model.layoutStyle == .fan else { return true }
        switch model.kind {
        case .applications:
            return model.applications.isEmpty
        case .windows, .hidden:
            return false
        case .message:
            return true
        }
    }

    private var activeContentPadding: CGFloat {
        if model.kind == .applications, !model.applications.isEmpty {
            return OverlayLayoutMetrics.applicationContentPadding
        }
        return OverlayLayoutMetrics.contentPadding
    }

    private var applicationContent: some View {
        Group {
            if model.applications.isEmpty {
                HStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 28, weight: .medium))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("overlay.no_bindings")
                            .font(.headline)
                        Text("overlay.no_bindings_detail")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("common.open_settings") { model.onOpenSettings?() }
                        .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 18)
            } else {
                CenteredHorizontalScroll {
                    switch model.layoutStyle {
                    case .horizontal:
                        HStack(spacing: OverlayLayoutMetrics.applicationItemSpacing) {
                            ForEach(model.applications) { binding in
                                ApplicationOverlayButton(
                                    binding: binding,
                                    modifier: model.switchingModifier,
                                    layoutStyle: .horizontal,
                                    individualSurfaceOpacity: nil,
                                    onSelect: model.onSelectApplication
                                )
                            }
                        }
                    case .fan:
                        FanApplicationLayout(
                            applications: model.applications,
                            modifier: model.switchingModifier,
                            revealedItemCount: model.fanRevealedItemCount,
                            surfaceOpacity: model.backgroundOpacity,
                            onSelect: model.onSelectApplication
                        )
                    }
                }
            }
        }
    }

    private var windowContent: some View {
        ScrollViewReader { proxy in
            CenteredHorizontalScroll {
                switch model.layoutStyle {
                case .horizontal:
                    HStack(spacing: OverlayLayoutMetrics.windowItemSpacing) {
                        ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                            WindowOverlayButton(
                                window: window,
                                index: index,
                                isSelected: index == model.selectedIndex,
                                layoutStyle: .horizontal,
                                individualSurfaceOpacity: nil,
                                onSelect: model.onSelectWindow
                            )
                        }
                    }
                case .fan:
                    FanWindowLayout(
                        windows: model.windows,
                        selectedIndex: model.selectedIndex,
                        revealedItemCount: model.fanRevealedItemCount,
                        surfaceOpacity: model.backgroundOpacity,
                        onSelect: model.onSelectWindow
                    )
                }
            }
            .onAppear {
                guard model.windows.indices.contains(model.selectedIndex) else { return }
                proxy.scrollTo(model.windows[model.selectedIndex].id, anchor: .center)
            }
            .onChange(of: model.selectedIndex) { _, newValue in
                guard model.windows.indices.contains(newValue) else { return }
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    proxy.scrollTo(model.windows[newValue].id, anchor: .center)
                } else {
                    withAnimation(.snappy(duration: 0.18)) {
                        proxy.scrollTo(model.windows[newValue].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var messageContent: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 24, weight: .medium))
            Text(model.message)
                .font(.headline)
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
    }
}

private struct ApplicationOverlayButton: View {
    let binding: AppBinding
    let modifier: SwitchingModifier
    let layoutStyle: OverlayLayoutStyle
    let individualSurfaceOpacity: Double?
    let onSelect: ((AppBinding) -> Void)?

    var body: some View {
        Button {
            onSelect?(binding)
        } label: {
            ApplicationOverlayCard(
                binding: binding,
                modifier: modifier,
                layoutStyle: layoutStyle,
                individualSurfaceOpacity: individualSurfaceOpacity
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(binding.displayName)
    }
}

private struct WindowOverlayButton: View {
    let window: WindowDescriptor
    let index: Int
    let isSelected: Bool
    let layoutStyle: OverlayLayoutStyle
    let individualSurfaceOpacity: Double?
    let onSelect: ((WindowDescriptor) -> Void)?

    var body: some View {
        Button {
            onSelect?(window)
        } label: {
            WindowOverlayCard(
                window: window,
                index: index,
                isSelected: isSelected,
                layoutStyle: layoutStyle,
                individualSurfaceOpacity: individualSurfaceOpacity
            )
        }
        .buttonStyle(.plain)
        .id(window.id)
    }
}

private struct FanApplicationLayout: View {
    let applications: [AppBinding]
    let modifier: SwitchingModifier
    let revealedItemCount: Int
    let surfaceOpacity: Double
    let onSelect: ((AppBinding) -> Void)?

    var body: some View {
        let geometry = OverlayLayoutMetrics.applicationFanGeometry(itemCount: applications.count)
        ZStack(alignment: .topLeading) {
            ForEach(Array(applications.enumerated()), id: \.element.id) { index, binding in
                let transform = geometry.transform(at: index)
                let isRevealed = index < revealedItemCount
                ApplicationOverlayButton(
                    binding: binding,
                    modifier: modifier,
                    layoutStyle: .fan,
                    individualSurfaceOpacity: surfaceOpacity,
                    onSelect: onSelect
                )
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .modifier(
                        FanRevealModifier(
                            transform: transform,
                            rotationAnchor: geometry.rotationAnchor,
                            revealOriginRotationDegrees: geometry.revealOriginRotationDegrees,
                            isRevealed: isRevealed
                        )
                    )
                    .zIndex(transform.zIndex)
            }
        }
        .frame(width: geometry.contentSize.width, height: geometry.contentSize.height, alignment: .topLeading)
    }
}

private struct FanWindowLayout: View {
    let windows: [WindowDescriptor]
    let selectedIndex: Int
    let revealedItemCount: Int
    let surfaceOpacity: Double
    let onSelect: ((WindowDescriptor) -> Void)?

    var body: some View {
        let geometry = OverlayLayoutMetrics.windowFanGeometry(itemCount: windows.count)
        ZStack(alignment: .topLeading) {
            ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                let transform = geometry.transform(at: index)
                let isSelected = index == selectedIndex
                let isRevealed = index < revealedItemCount
                WindowOverlayButton(
                    window: window,
                    index: index,
                    isSelected: isSelected,
                    layoutStyle: .fan,
                    individualSurfaceOpacity: surfaceOpacity,
                    onSelect: onSelect
                )
                .compositingGroup()
                .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
                .modifier(
                    FanRevealModifier(
                        transform: transform,
                        rotationAnchor: geometry.rotationAnchor,
                        revealOriginRotationDegrees: geometry.revealOriginRotationDegrees,
                        isRevealed: isRevealed
                    )
                )
                .zIndex(isSelected ? Double(windows.count + 1) : transform.zIndex)
            }
        }
        .frame(width: geometry.contentSize.width, height: geometry.contentSize.height, alignment: .topLeading)
    }
}

private struct FanRevealModifier: ViewModifier {
    let transform: OverlayFanItemTransform
    let rotationAnchor: UnitPoint
    let revealOriginRotationDegrees: Double
    let isRevealed: Bool

    func body(content: Content) -> some View {
        content
            .rotationEffect(
                .degrees(
                    isRevealed
                        ? transform.rotationDegrees
                        : revealOriginRotationDegrees
                ),
                anchor: rotationAnchor
            )
            .offset(transform.offset)
            .opacity(isRevealed ? 1 : 0)
            .allowsHitTesting(isRevealed)
    }
}

private struct CenteredHorizontalScroll<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content
                .padding(.horizontal, OverlayLayoutMetrics.scrollPadding)
        }
        .defaultScrollAnchor(.center, for: .alignment)
    }
}

private struct ApplicationOverlayCard: View {
    let binding: AppBinding
    let modifier: SwitchingModifier
    let layoutStyle: OverlayLayoutStyle
    let individualSurfaceOpacity: Double?

    private var isFan: Bool { layoutStyle == .fan }

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: AppResolver.icon(for: binding))
                .resizable()
                .scaledToFit()
                .frame(
                    width: isFan
                        ? OverlayLayoutMetrics.applicationFanIconSize
                        : OverlayLayoutMetrics.applicationIconSize,
                    height: isFan
                        ? OverlayLayoutMetrics.applicationFanIconSize
                        : OverlayLayoutMetrics.applicationIconSize
                )
            Text(
                OverlayLayoutMetrics.applicationShortcutText(
                    for: binding.keyBinding,
                    modifier: modifier,
                    layoutStyle: layoutStyle
                )
            )
                .font(
                    isFan
                        ? .system(
                            size: OverlayLayoutMetrics.applicationFanShortcutFontSize,
                            weight: .semibold,
                            design: .monospaced
                        )
                        : .caption2.monospaced().weight(.semibold)
                )
                .padding(.horizontal, isFan ? 4 : 8)
                .padding(.vertical, isFan ? 2 : 3)
                .background(.primary.opacity(0.08), in: Capsule())
        }
        .frame(
            width: OverlayLayoutMetrics.applicationCardWidth,
            height: OverlayLayoutMetrics.applicationCardHeight
        )
        .background {
            if let individualSurfaceOpacity {
                RoundedRectangle(
                    cornerRadius: OverlayLayoutMetrics.fanCardCornerRadius,
                    style: .continuous
                )
                    .fill(.regularMaterial)
                    .opacity(individualSurfaceOpacity)
            }
        }
        .overlay {
            if individualSurfaceOpacity != nil {
                RoundedRectangle(
                    cornerRadius: OverlayLayoutMetrics.fanCardCornerRadius,
                    style: .continuous
                )
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: isFan ? OverlayLayoutMetrics.fanCardCornerRadius : 18,
                style: .continuous
            )
        )
    }
}

private struct WindowOverlayCard: View {
    let window: WindowDescriptor
    let index: Int
    let isSelected: Bool
    let layoutStyle: OverlayLayoutStyle
    let individualSurfaceOpacity: Double?

    private var iconSize: CGFloat {
        layoutStyle == .fan
            ? OverlayLayoutMetrics.windowFanIconSize
            : OverlayLayoutMetrics.windowIconSize
    }

    private var cornerRadius: CGFloat {
        layoutStyle == .fan ? OverlayLayoutMetrics.fanCardCornerRadius : 16
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: window.applicationIcon)
                .resizable()
                .scaledToFit()
                .frame(
                    width: iconSize,
                    height: iconSize
                )
            Text(window.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            if let badge = WindowNumbering.badge(forZeroBasedIndex: index) {
                Text("\(badge)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .frame(width: 20, height: 20)
                    .background(.primary.opacity(0.1), in: Circle())
            }
        }
        .padding(.horizontal, OverlayLayoutMetrics.windowCardHorizontalPadding)
        .frame(width: OverlayLayoutMetrics.windowCardWidth, height: OverlayLayoutMetrics.windowCardHeight)
        .background {
            if let individualSurfaceOpacity {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(individualSurfaceOpacity)
            }
        }
        .background(
            isSelected ? Color.primary.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(isSelected ? Color.primary.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
