import AppKit
import SwiftUI

struct OverlayRootView: View {
    @ObservedObject var model: OverlayViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.regularMaterial)
                .opacity(model.backgroundOpacity)
                .allowsHitTesting(false)

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
                    HStack(spacing: OverlayLayoutMetrics.applicationItemSpacing) {
                        ForEach(model.applications) { binding in
                            Button {
                                model.onSelectApplication?(binding)
                            } label: {
                                ApplicationOverlayCard(
                                    binding: binding,
                                    modifier: model.switchingModifier
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(binding.displayName)
                        }
                    }
                }
            }
        }
    }

    private var windowContent: some View {
        ScrollViewReader { proxy in
            CenteredHorizontalScroll {
                HStack(spacing: OverlayLayoutMetrics.windowItemSpacing) {
                    ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                        Button {
                            model.onSelectWindow?(window)
                        } label: {
                            WindowOverlayCard(window: window, index: index, isSelected: index == model.selectedIndex)
                        }
                        .buttonStyle(.plain)
                        .id(window.id)
                    }
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

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: AppResolver.icon(for: binding))
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
            Text(binding.keyBinding.displayText(modifier: modifier))
                .font(.caption2.monospaced().weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.primary.opacity(0.08), in: Capsule())
        }
        .frame(
            width: OverlayLayoutMetrics.applicationCardWidth,
            height: OverlayLayoutMetrics.applicationCardHeight
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct WindowOverlayCard: View {
    let window: WindowDescriptor
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: window.applicationIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
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
        .padding(.horizontal, 12)
        .frame(width: OverlayLayoutMetrics.windowCardWidth, height: OverlayLayoutMetrics.windowCardHeight)
        .background(isSelected ? Color.primary.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.primary.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
