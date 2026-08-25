import AppKit
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case bindings
    case about

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .general: "settings.general"
        case .bindings: "settings.bindings"
        case .about: "settings.about"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .bindings: "command"
        case .about: "info.circle"
        }
    }
}

struct SettingsRootView: View {
    @ObservedObject var model: AppModel
    @State private var selection: SettingsSection = .general
    private let settingsBackground = Color(nsColor: .windowBackgroundColor)

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Whirl")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                List(SettingsSection.allCases, selection: $selection) { section in
                    Label(section.titleKey, systemImage: section.symbol)
                        .tag(section)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(settingsBackground)
            }
            .frame(width: 190)
            .background(settingsBackground)
            .accessibilityIdentifier("settings.sidebar")

            Divider()

            NavigationStack {
                Group {
                    switch selection {
                    case .general:
                        GeneralSettingsView(model: model)
                    case .bindings:
                        BindingsSettingsView(model: model)
                    case .about:
                        AboutView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(settingsBackground)
        }
        .frame(minWidth: 920, minHeight: 560)
        .background(settingsBackground)
    }
}
