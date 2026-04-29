import Foundation
import Combine

class TTSStore: ObservableObject {
    static let shared = TTSStore()

    @Published var config = TTSConfig() {
        didSet { save() }
    }

    private let storageKey = "com.preask.ttsconfig"

    private init() {
        load()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(TTSConfig.self, from: data) else {
            return
        }
        config = decoded
    }
}
