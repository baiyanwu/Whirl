import AppKit
import Combine
import SwiftUI

private enum SwitchingSettingsMode: String, CaseIterable, Identifiable {
    case applications
    case windows

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .applications: "general.trigger"
        case .windows: "general.window_switching"
        }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedMode = SwitchingSettingsMode.applications

    var body: some View {
        VStack(spacing: 0) {
            Picker("settings.general", selection: $selectedMode) {
                ForEach(SwitchingSettingsMode.allCases) { mode in
                    Text(mode.titleKey).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 12) {
                    switch selectedMode {
                    case .applications:
                        SettingsCard {
                            SettingsCardRow {
                                CompactSliderRow(
                                    title: "general.long_press",
                                    value: $model.preferences.longPressDuration,
                                    range: AppPreferences.minimumLongPressDuration
                                        ... AppPreferences.maximumLongPressDuration,
                                    step: 0.05,
                                    valueText: milliseconds(model.preferences.longPressDuration)
                                )
                            }
                            Divider()
                            SettingsCardRow {
                                CompactSliderRow(
                                    title: "general.overlay_vertical_position",
                                    value: verticalPositionSlider(\.applicationOverlayVerticalPosition),
                                    range: 0 ... 1,
                                    step: 0.025,
                                    valueText: verticalPosition(model.preferences.applicationOverlayVerticalPosition)
                                )
                            }
                            Divider()
                            SettingsCardRow {
                                CompactSliderRow(
                                    title: "general.overlay_opacity",
                                    value: $model.preferences.applicationOverlayOpacity,
                                    range: AppPreferences.minimumOverlayOpacity
                                        ... AppPreferences.maximumOverlayOpacity,
                                    step: 0.05,
                                    valueText: percentage(model.preferences.applicationOverlayOpacity)
                                )
                            }
                        }

                    case .windows:
                        SettingsCard {
                            SettingsCardRow {
                                PermissionRow(
                                    title: "permission.accessibility",
                                    detail: "permission.accessibility_detail",
                                    granted: model.permissions.accessibilityGranted,
                                    action: model.requestAccessibility
                                )
                            }
                            if !model.permissions.accessibilityGranted {
                                Divider()
                                SettingsCardRow {
                                    CompactPermissionRecoveryView(model: model)
                                }
                            }
                            Divider()
                            SettingsCardRow(verticalPadding: 8) {
                                WindowConfirmationKeySetting(
                                    selection: $model.preferences.windowConfirmationKey
                                )
                            }
                            Divider()
                            SettingsCardRow {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("general.include_tabs")
                                        Text("general.include_tabs_detail")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 16)

                                    Toggle(
                                        "general.include_tabs",
                                        isOn: $model.preferences.includeApplicationTabs
                                    )
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .fixedSize()
                                }
                            }
                            Divider()
                            SettingsCardRow {
                                CompactSliderRow(
                                    title: "general.double_tap",
                                    value: $model.preferences.doubleTapInterval,
                                    range: 0.2 ... 0.6,
                                    step: 0.05,
                                    valueText: milliseconds(model.preferences.doubleTapInterval)
                                )
                            }
                            Divider()
                            SettingsCardRow {
                                CompactSliderRow(
                                    title: "general.window_picker_duration",
                                    value: $model.preferences.windowPickerDisplayDuration,
                                    range: AppPreferences.minimumWindowPickerDisplayDuration
                                        ... AppPreferences.maximumWindowPickerDisplayDuration,
                                    step: 1,
                                    valueText: seconds(model.preferences.windowPickerDisplayDuration)
                                )
                            }
                            Divider()
                            SettingsCardRow {
                                CompactSliderRow(
                                    title: "general.overlay_vertical_position",
                                    value: verticalPositionSlider(\.windowOverlayVerticalPosition),
                                    range: 0 ... 1,
                                    step: 0.025,
                                    valueText: verticalPosition(model.preferences.windowOverlayVerticalPosition)
                                )
                            }
                            Divider()
                            SettingsCardRow {
                                CompactSliderRow(
                                    title: "general.overlay_opacity",
                                    value: $model.preferences.windowOverlayOpacity,
                                    range: AppPreferences.minimumOverlayOpacity
                                        ... AppPreferences.maximumOverlayOpacity,
                                    step: 0.05,
                                    valueText: percentage(model.preferences.windowOverlayOpacity)
                                )
                            }
                        }
                    }

                    if let error = model.settingsError {
                        SettingsCard {
                            SettingsCardRow {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            GlobalSettingsBar(
                switchingModifier: $model.preferences.switchingModifier,
                overlayLayoutStyle: $model.preferences.overlayLayoutStyle,
                launchAtLogin: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            .padding(.bottom, 32)
        }
        .navigationTitle("settings.general")
        .onAppear { model.refreshLaunchAtLoginStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshPermissions()
        }
    }

    private func milliseconds(_ seconds: Double) -> String {
        String(format: String(localized: "format.milliseconds"), Int((seconds * 1_000).rounded()))
    }

    private func seconds(_ value: Double) -> String {
        String(format: String(localized: "format.seconds"), Int(value.rounded()))
    }

    private func verticalPosition(_ value: Double) -> String {
        guard abs(value) >= 0.005 else {
            return String(localized: "general.overlay_centered")
        }
        return String(
            format: String(localized: "format.percent"),
            Int((value * 100).rounded())
        )
    }

    private func percentage(_ value: Double) -> String {
        String(format: String(localized: "format.percentage"), Int((value * 100).rounded()))
    }

    private func verticalPositionSlider(
        _ keyPath: WritableKeyPath<AppPreferences, Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                let position = model.preferences[keyPath: keyPath]
                return min(max((position + 1) / 2, 0), 1)
            },
            set: { normalizedValue in
                let snappedValue = (normalizedValue / 0.025).rounded() * 0.025
                model.preferences[keyPath: keyPath] = AppPreferences.normalizedOverlayVerticalPosition(
                    snappedValue * 2 - 1
                )
            }
        )
    }
}

private struct WindowConfirmationKeySetting: View {
    @Binding var selection: WindowConfirmationKey

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 14) {
                Text("general.window_confirmation_key")
                Spacer(minLength: 20)
                Picker("general.window_confirmation_key", selection: $selection) {
                    ForEach(WindowConfirmationKey.allCases) { key in
                        Text(verbatim: key.displayTitle)
                            .tag(key)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 190, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)

            Text("general.window_number_shortcut_tip")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
    }
}

private struct SettingsCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.13))
        }
    }
}

private struct SettingsCardRow<Content: View>: View {
    let verticalPadding: CGFloat
    private let content: Content

    init(verticalPadding: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.verticalPadding = verticalPadding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
    }
}

private struct GlobalSettingsBar: View {
    @Binding var switchingModifier: SwitchingModifier
    @Binding var overlayLayoutStyle: OverlayLayoutStyle
    @Binding var launchAtLogin: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("general.overlay_layout")
                    Text("general.overlay_layout_detail")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                Picker("general.overlay_layout", selection: $overlayLayoutStyle) {
                    ForEach(OverlayLayoutStyle.allCases) { layoutStyle in
                        Text(LocalizedStringKey(layoutStyle.localizedKey))
                            .tag(layoutStyle)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 190, alignment: .trailing)
                .accessibilityIdentifier("overlay.layout.picker")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 22)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("general.switching_modifier")
                    Text("general.switching_modifier_scope")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                Picker("general.switching_modifier", selection: $switchingModifier) {
                    ForEach(SwitchingModifier.allCases) { modifier in
                        Label {
                            Text(LocalizedStringKey(modifier.localizedKey))
                        } icon: {
                            Image(systemName: modifier.systemImageName)
                        }
                        .tag(modifier)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 190, alignment: .trailing)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 22)

            HStack {
                Toggle("general.launch_at_login", isOn: $launchAtLogin)
                    .fixedSize()
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
    }
}

private struct CompactSliderRow: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: String

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
            Spacer(minLength: 20)
            Slider(value: steppedValue, in: range)
                .tint(.accentColor)
                .frame(width: 220)
            Text(valueText)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
        }
        .frame(minHeight: 28)
    }

    private var steppedValue: Binding<Double> {
        Binding(
            get: { value },
            set: { newValue in
                let stepCount = ((newValue - range.lowerBound) / step).rounded()
                value = min(max(range.lowerBound + stepCount * step, range.lowerBound), range.upperBound)
            }
        )
    }
}

private struct CompactPermissionRecoveryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            if let notice = model.permissionNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            Button("permission.refresh") { model.verifyPermissions() }
            Button("permission.restart") { model.restartApplication() }
        }
    }
}

struct PermissionRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("permission.authorize", action: action)
            }
        }
    }
}

struct PermissionHelpView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("permission.refresh") { model.verifyPermissions() }
                if model.permissions.allGranted {
                    Label("permission.status_ready", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                }
            }

            if let notice = model.permissionNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(model.permissions.allGranted ? .green : .secondary)
            }

            if !model.permissions.allGranted {
                Text("permission.troubleshooting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                #if DEBUG
                Text("permission.debug_signature_note")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                #endif
                Button("permission.restart") { model.restartApplication() }
            }
        }
    }
}
