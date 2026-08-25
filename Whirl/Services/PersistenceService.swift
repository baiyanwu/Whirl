import Foundation

struct PersistenceService {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let bindings = "whirl.bindings.v1"
        static let preferences = "whirl.preferences.v1"
        static let welcomeCompleted = "whirl.welcome.completed"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadBindings() -> [AppBinding] {
        guard let data = defaults.data(forKey: Keys.bindings),
              let bindings = try? decoder.decode([AppBinding].self, from: data) else { return [] }
        return bindings.sorted { $0.order < $1.order }
    }

    func saveBindings(_ bindings: [AppBinding]) {
        guard let data = try? encoder.encode(bindings) else { return }
        defaults.set(data, forKey: Keys.bindings)
    }

    func loadPreferences() -> AppPreferences {
        guard let data = defaults.data(forKey: Keys.preferences),
              let preferences = try? decoder.decode(AppPreferences.self, from: data) else { return .default }
        return preferences
    }

    func savePreferences(_ preferences: AppPreferences) {
        guard let data = try? encoder.encode(preferences) else { return }
        defaults.set(data, forKey: Keys.preferences)
    }

    var hasCompletedWelcome: Bool {
        get { defaults.bool(forKey: Keys.welcomeCompleted) }
        nonmutating set { defaults.set(newValue, forKey: Keys.welcomeCompleted) }
    }
}
