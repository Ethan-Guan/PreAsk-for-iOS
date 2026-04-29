import Foundation

// MARK: - TTS 请求模型
struct TTSRequest: Encodable {
    let model: String
    let messages: [TTSMessage]
    let audio: TTSAudio

    struct TTSMessage: Encodable {
        let role: String
        let content: String
    }

    struct TTSAudio: Encodable {
        let format: String
        let voice: String
    }
}

// MARK: - TTS 响应模型
struct TTSResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: AudioMessage

        struct AudioMessage: Decodable {
            let audio: AudioData

            struct AudioData: Decodable {
                let data: String
            }
        }
    }
}

// MARK: - TTS API 管理器
class TTSService {
    static let shared = TTSService()

    private init() {}

    private var config: TTSConfig {
        TTSStore.shared.config
    }

    func synthesize(text: String) async throws -> Data {
        guard config.isConfigured else {
            throw NSError(domain: "TTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "TTS未配置：请设置API Key"])
        }

        guard let url = URL(string: config.baseURL) else {
            throw NSError(domain: "TTS", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的TTS API地址"])
        }

        let voiceBase64 = try loadAndEncodeVoiceSample()

        let styleContent = config.styleInstruction.isEmpty ? "用自然语气朗读" : config.styleInstruction

        let requestBody = TTSRequest(
            model: config.model,
            messages: [
                TTSRequest.TTSMessage(role: "user", content: styleContent),
                TTSRequest.TTSMessage(role: "assistant", content: text)
            ],
            audio: TTSRequest.TTSAudio(
                format: "wav",
                voice: "data:audio/wav;base64,\(voiceBase64)"
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw NSError(domain: "TTS", code: -3, userInfo: [NSLocalizedDescriptionKey: "请求体编码失败"])
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TTS", code: -4, userInfo: [NSLocalizedDescriptionKey: "无效的服务器响应"])
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "无响应体"
            throw NSError(domain: "TTS", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API请求失败 (\(httpResponse.statusCode))：\(body)"])
        }

        do {
            let ttsResponse = try JSONDecoder().decode(TTSResponse.self, from: data)
            guard let audioBase64 = ttsResponse.choices.first?.message.audio.data,
                  let audioData = Data(base64Encoded: audioBase64) else {
                throw NSError(domain: "TTS", code: -5, userInfo: [NSLocalizedDescriptionKey: "API返回空音频数据"])
            }
            return audioData
        } catch {
            throw NSError(domain: "TTS", code: -6, userInfo: [NSLocalizedDescriptionKey: "响应解析失败：\(error.localizedDescription)"])
        }
    }

    private func loadAndEncodeVoiceSample() throws -> String {
        guard let resourceURL = Bundle.main.url(forResource: "Moss", withExtension: "wav") else {
            throw NSError(domain: "TTS", code: -7, userInfo: [NSLocalizedDescriptionKey: "找不到声音样本：Moss.wav（请确保文件已添加到项目资源中）"])
        }
        let voiceData = try Data(contentsOf: resourceURL)
        return voiceData.base64EncodedString()
    }
}
