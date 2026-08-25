import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BindingsSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var applications: [InstalledApplication] = []
    @State private var searchText = ""
    @State private var selectedApplication: InstalledApplication?
    @State private var pendingApplication: InstalledApplication?
    @State private var editingBindingID: UUID?
    @State private var error: String?

    private var displayedApplications: [InstalledApplication] {
        let filtered = searchText.isEmpty ? applications : applications.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted(by: applicationComesBefore)
    }

    private var isCapturingKey: Bool {
        pendingApplication != nil || editingBindingID != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HSplitView {
                ApplicationLibraryView(
                    applications: displayedApplications,
                    searchText: $searchText,
                    selection: $selectedApplication,
                    isConfigured: isConfigured,
                    canConfigure: model.bindings.count < 36,
                    onConfigure: beginConfiguring
                )
                .frame(minWidth: 250, idealWidth: 290, maxWidth: 340, maxHeight: .infinity)

                ConfiguredApplicationsView(
                    model: model,
                    pendingApplication: $pendingApplication,
                    editingBindingID: $editingBindingID,
                    error: $error
                )
                .frame(minWidth: 420, idealWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("settings.bindings")
        .task { applications = model.scanInstalledApplications() }
        .onChange(of: isCapturingKey, initial: true) { _, isCapturing in
            model.suspendHotKeys(isCapturing)
        }
        .onDisappear { model.suspendHotKeys(false) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("bindings.title")
                    .font(.title2.bold())
                Text("bindings.subtitle")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: chooseOtherApplication) {
                Label("add_app.choose_other", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("bindings.choose_other")
        }
        .padding(24)
    }

    private func isConfigured(_ application: InstalledApplication) -> Bool {
        configuredIndex(for: application) != nil
    }

    private func configuredIndex(for application: InstalledApplication) -> Int? {
        model.bindings.firstIndex { binding in
            (!application.bundleIdentifier.isEmpty
                && binding.bundleIdentifier == application.bundleIdentifier)
                || binding.storedPath == application.url.path
        }
    }

    private func applicationComesBefore(
        _ lhs: InstalledApplication,
        _ rhs: InstalledApplication
    ) -> Bool {
        switch (configuredIndex(for: lhs), configuredIndex(for: rhs)) {
        case let (lhsIndex?, rhsIndex?):
            return lhsIndex < rhsIndex
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            let nameOrder = lhs.displayName.localizedStandardCompare(rhs.displayName)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return lhs.bundleIdentifier.localizedStandardCompare(rhs.bundleIdentifier) == .orderedAscending
        }
    }

    private func beginConfiguring(_ application: InstalledApplication) {
        selectedApplication = application
        editingBindingID = nil
        error = nil

        guard model.bindings.count < 36 else {
            pendingApplication = nil
            error = String(localized: "binding.error.limit")
            return
        }
        guard !isConfigured(application) else {
            pendingApplication = nil
            error = String(localized: "binding.error.duplicate_app")
            return
        }
        pendingApplication = application
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

        if let existingIndex = applications.firstIndex(where: { $0.id == application.id }) {
            applications[existingIndex] = application
        } else {
            applications.insert(application, at: 0)
        }
        beginConfiguring(application)
    }
}

private struct ApplicationLibraryView: View {
    let applications: [InstalledApplication]
    @Binding var searchText: String
    @Binding var selection: InstalledApplication?
    let isConfigured: (InstalledApplication) -> Bool
    let canConfigure: Bool
    let onConfigure: (InstalledApplication) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("bindings.available_apps")
                    .font(.headline)
                Spacer()
                Text(applications.count, format: .number)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            TextField("add_app.search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            Divider()

            if applications.isEmpty, !searchText.isEmpty {
                ContentUnavailableView(
                    "bindings.search_empty",
                    systemImage: "magnifyingglass",
                    description: Text(searchText)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(applications, selection: $selection) { application in
                    HStack(spacing: 10) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: application.url.path))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(application.displayName)
                                .lineLimit(1)
                                .accessibilityIdentifier("library.name.\(application.id)")
                            Text(application.bundleIdentifier)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 6)

                        if isConfigured(application) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityLabel(Text("bindings.configured"))
                        } else {
                            Button {
                                onConfigure(application)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!canConfigure)
                            .help("bindings.configure")
                            .accessibilityLabel(Text("bindings.configure"))
                            .accessibilityIdentifier("library.configure.\(application.id)")
                        }
                    }
                    .tag(application)
                }
                .listStyle(.inset)
            }
        }
    }
}
