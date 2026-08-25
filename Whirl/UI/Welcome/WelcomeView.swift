import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @ObservedObject var model: AppModel
    let onFinish: () -> Void

    @State private var step = 0
    @State private var selectedApplication: InstalledApplication?
    @State private var selectedKey: KeyBinding?
    @State private var showingApplicationPicker = false
    @State private var bindingError: String?

    private let stepCount = 5

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(0 ..< stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.primary : Color.primary.opacity(0.12))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)

            Group {
                switch step {
                case 0: introduction
                case 1: permissions
                case 2: triggerSelection
                case 3: firstBinding
                default: completion
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(34)

            Divider()
            HStack {
                if step > 0 && step < stepCount - 1 {
                    Button("common.back") { step -= 1 }
                }
                Spacer()
                if step == 3 && selectedApplication == nil {
                    Button("welcome.configure_later") { step += 1 }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Button(step == stepCount - 1 ? "welcome.finish" : "common.continue") {
                    advance()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 720, height: 520)
        .sheet(isPresented: $showingApplicationPicker) {
            WelcomeApplicationPicker(model: model) { application in
                selectedApplication = application
                selectedKey = nil
            }
        }
        .onChange(of: step) { _, newStep in
            model.suspendHotKeys(newStep == 3)
        }
        .onDisappear { model.suspendHotKeys(false) }
    }

    private var introduction: some View {
        VStack(spacing: 24) {
            Image(systemName: "wind")
                .font(.system(size: 72, weight: .thin))
                .symbolEffect(.breathe)
            Text("welcome.title")
                .font(.largeTitle.bold())
            Text("welcome.subtitle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
            HStack(spacing: 30) {
                FeatureBadge(symbol: "keyboard", title: "welcome.feature_shortcut")
                FeatureBadge(symbol: "rectangle.split.3x1", title: "welcome.feature_apps")
                FeatureBadge(symbol: "macwindow.on.rectangle", title: "welcome.feature_windows")
            }
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("welcome.permissions_title").font(.largeTitle.bold())
            Text("welcome.permissions_detail").foregroundStyle(.secondary)
            PermissionRow(
                title: "permission.accessibility",
                detail: "permission.accessibility_detail",
                granted: model.permissions.accessibilityGranted,
                action: model.requestAccessibility
            )
            .padding(16)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            PermissionHelpView(model: model)
            Spacer()
        }
    }

    private var triggerSelection: some View {
        VStack(spacing: 26) {
            Image(systemName: "keyboard")
                .font(.system(size: 64, weight: .thin))
            Text("welcome.trigger_title").font(.largeTitle.bold())
            Text("welcome.trigger_detail")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Picker("general.switching_modifier", selection: $model.preferences.switchingModifier) {
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
            .frame(width: 220)
            Spacer()
        }
    }

    private var firstBinding: some View {
        VStack(spacing: 18) {
            Text("welcome.binding_title").font(.largeTitle.bold())
            Text("welcome.binding_detail")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let selectedApplication {
                Image(nsImage: NSWorkspace.shared.icon(forFile: selectedApplication.url.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                Text(selectedApplication.displayName).font(.title3.bold())
                Button("welcome.change_app") { showingApplicationPicker = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                KeyCaptureView { selectedKey = $0 }
                    .frame(width: 260, height: 68)
                if let selectedKey {
                    Text(selectedKey.displayText(modifier: model.preferences.switchingModifier))
                        .font(.title3.monospaced().bold())
                }
            } else {
                Button {
                    showingApplicationPicker = true
                } label: {
                    Label("bindings.add", systemImage: "plus.app")
                        .frame(width: 230, height: 62)
                }
                .buttonStyle(.borderedProminent)
            }

            if let bindingError {
                Text(bindingError).font(.caption).foregroundStyle(.red)
            }
            Spacer()
        }
    }

    private var completion: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: step)
            Text("welcome.done_title").font(.largeTitle.bold())
            Text("welcome.done_detail")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
            VStack(alignment: .leading, spacing: 12) {
                Label("welcome.try_shortcut", systemImage: "command")
                Label("welcome.try_hold", systemImage: "rectangle.split.3x1")
                Label("welcome.try_double", systemImage: "macwindow.on.rectangle")
            }
            .font(.headline)
        }
    }

    private func advance() {
        if step == 3, let selectedApplication, let selectedKey {
            if let message = model.addBinding(application: selectedApplication, keyBinding: selectedKey) {
                bindingError = message
                return
            }
        }
        if step == stepCount - 1 {
            model.completeWelcome()
            onFinish()
        } else {
            step += 1
        }
    }
}

private struct FeatureBadge: View {
    let symbol: String
    let title: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title2)
            Text(title).font(.caption).multilineTextAlignment(.center)
        }
        .frame(width: 130, height: 76)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct WelcomeApplicationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: AppModel
    let onSelect: (InstalledApplication) -> Void
    @State private var applications: [InstalledApplication] = []
    @State private var searchText = ""

    private var filtered: [InstalledApplication] {
        searchText.isEmpty ? applications : applications.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("add_app.select_prompt").font(.title2.bold())
                Spacer()
                Button("add_app.choose_other") { chooseOtherApplication() }
            }
            TextField("add_app.search", text: $searchText).textFieldStyle(.roundedBorder)
            List(filtered) { application in
                Button {
                    onSelect(application)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: application.url.path))
                            .resizable().scaledToFit().frame(width: 32, height: 32)
                        Text(application.displayName)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 470, height: 470)
        .task { applications = model.scanInstalledApplications() }
    }

    private func chooseOtherApplication() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if let applicationBundleType = UTType(filenameExtension: "app") {
            panel.allowedContentTypes = [applicationBundleType]
        }
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK,
              let url = panel.url,
              let application = model.applicationFromURL(url) else { return }
        onSelect(application)
        dismiss()
    }
}
