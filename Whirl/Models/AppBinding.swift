import Foundation

struct AppBinding: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var bundleIdentifier: String
    var displayName: String
    var storedPath: String
    var bookmarkData: Data?
    var keyBinding: KeyBinding
    var order: Int

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        displayName: String,
        storedPath: String,
        bookmarkData: Data?,
        keyBinding: KeyBinding,
        order: Int
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.storedPath = storedPath
        self.bookmarkData = bookmarkData
        self.keyBinding = keyBinding
        self.order = order
    }
}
struct InstalledApplication: Identifiable, Hashable, Sendable {
    let url: URL
    let bundleIdentifier: String
    let displayName: String

    var id: String { bundleIdentifier.isEmpty ? url.path : bundleIdentifier }
}
