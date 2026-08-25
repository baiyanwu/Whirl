import AppKit
import SwiftUI

struct AboutView: View {
    private let githubURL = URL(string: "https://github.com/baiyanwu/Whirl")

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .shadow(radius: 8, y: 4)
            Text("Whirl")
                .font(.largeTitle.bold())
            Text(versionText)
                .foregroundStyle(.secondary)
            Divider().frame(width: 280)
            LabeledContent("about.developer", value: "baiyanwu")
                .frame(width: 280)
            if let githubURL {
                Link(destination: githubURL) {
                    LabeledContent("about.github", value: githubURL.absoluteString)
                }
                .frame(width: 280)
            }
            Text("about.tagline")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .padding(.top, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("settings.about")
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return String(format: String(localized: "about.version_format"), version, build)
    }
}
