import Foundation

struct TTSConfig: Codable {
    var apiKey: String = ""
    var baseURL: String = "https://api.xiaomimimo.com/v1/chat/completions"
    var model: String = "mimo-v2.5-tts-voiceclone"
    var styleInstruction: String = ""

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    static let voiceSampleName = "Moss.wav"
}
