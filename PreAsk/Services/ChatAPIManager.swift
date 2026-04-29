import Foundation

// MARK: - API 请求模型
struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [APIMessage]
    let enable_search: Bool?
    let chat_template_kwargs: ChatTemplateKwargs?
    let stream: Bool

    init(model: String, messages: [APIMessage], enableSearch: Bool, enableThinking: Bool, stream: Bool = false) {
        self.model = model
        self.messages = messages
        self.enable_search = enableSearch ? true : nil
        self.chat_template_kwargs = enableThinking ? ChatTemplateKwargs(enable_thinking: true) : nil
        self.stream = stream
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case enable_search
        case chat_template_kwargs
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(stream, forKey: .stream)
        if let search = enable_search {
            try container.encode(search, forKey: .enable_search)
        }
        if let kwargs = chat_template_kwargs {
            try container.encode(kwargs, forKey: .chat_template_kwargs)
        }
    }
}

struct ChatTemplateKwargs: Encodable {
    let enable_thinking: Bool
}

struct APIMessage: Encodable {
    let role: String
    let content: ContentType
    let reasoning_content: String?

    init(role: String, text: String, reasoningContent: String? = nil) {
        self.role = role
        self.content = .text(text)
        self.reasoning_content = reasoningContent
    }

    init(role: String, imageURLs: [String], text: String?, reasoningContent: String? = nil) {
        self.role = role
        var parts: [ContentPart] = []
        if let text {
            parts.append(.text(ContentTextPart(text: text)))
        }
        for url in imageURLs {
            parts.append(.image(ContentImagePart(image_url: ImageURLPart(url: url))))
        }
        self.content = .multipart(parts)
        self.reasoning_content = reasoningContent
    }

    enum CodingKeys: String, CodingKey {
        case role, content
        case reasoning_content
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        switch content {
        case .text(let t):
            try container.encode(t, forKey: .content)
        case .multipart(let parts):
            try container.encode(parts, forKey: .content)
        }
        if let rc = reasoning_content {
            try container.encode(rc, forKey: .reasoning_content)
        }
    }
}

enum ContentType {
    case text(String)
    case multipart([ContentPart])
}

enum ContentPart: Encodable {
    case text(ContentTextPart)
    case image(ContentImagePart)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let p):
            try container.encode(p)
        case .image(let p):
            try container.encode(p)
        }
    }
}

struct ContentTextPart: Encodable {
    let type = "text"
    let text: String
}

struct ContentImagePart: Encodable {
    let type = "image_url"
    let image_url: ImageURLPart
}

struct ImageURLPart: Encodable {
    let url: String
    let detail: String?

    init(url: String, detail: String? = nil) {
        self.url = url
        self.detail = detail
    }
}

// MARK: - API 响应模型
struct ChatCompletionResponse: Decodable {
    let id: String?
    let choices: [Choice]
    let error: APIError?

    struct Choice: Decodable {
        let index: Int?
        let message: ResponseMessage
        let finish_reason: String?

        struct ResponseMessage: Decodable {
            let role: String?
            let content: String?
            let reasoning_content: String?
        }
    }

    struct APIError: Decodable {
        let code: String?
        let message: String
        let type: String?
    }
}

// MARK: - 响应结果
struct ChatResult {
    let text: String
    let reasoning: String?
}

// MARK: - 流式响应模型
struct ChatStreamChunk: Decodable {
    let id: String?
    let choices: [StreamChoice]

    struct StreamChoice: Decodable {
        let index: Int?
        let delta: Delta
        let finish_reason: String?

        struct Delta: Decodable {
            let role: String?
            let content: String?
            let reasoning_content: String?
        }
    }
}

// MARK: - 网络请求管理器
class ChatAPIManager {
    static let shared = ChatAPIManager()

    private init() {}

    // MARK: - 公共接口（带多轮历史）

    func sendChatRequest(agent: Agent, messages: [Message]) async throws -> ChatResult {
        guard let url = URL(string: agent.baseURL) else {
            throw APIError.invalidURL
        }

        let apiMessages = buildAPIMessages(agent: agent, appMessages: messages)

        let requestBody = ChatCompletionRequest(
            model: agent.model,
            messages: apiMessages,
            enableSearch: agent.enableSearch,
            enableThinking: agent.enableThinking,
            stream: false
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeaderValue(for: agent), forHTTPHeaderField: authHeaderName(for: agent))
        request.timeoutInterval = 120

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw APIError.encodingFailed(error)
        }

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        guard let response = httpResponse as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= response.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "无响应体"
            throw APIError.httpError(response.statusCode, body)
        }

        do {
            let apiResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            if let error = apiResponse.error {
                throw APIError.serverError(error.message)
            }
            guard let choice = apiResponse.choices.first else {
                throw APIError.emptyResponse
            }
            let text = choice.message.content ?? ""
            return ChatResult(text: text, reasoning: choice.message.reasoning_content)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    // MARK: - 兼容旧接口

    func sendChatRequest(agent: Agent, text: String) async throws -> String {
        let msg = Message(text: text, isUser: true)
        let result = try await sendChatRequest(agent: agent, messages: [msg])
        return result.text
    }

    // MARK: - 流式请求

    func sendStreamingRequest(agent: Agent, messages: [Message], onChunk: @escaping @Sendable (String?, String?) -> Void) async throws {
        guard let url = URL(string: agent.baseURL) else {
            throw APIError.invalidURL
        }

        let apiMessages = buildAPIMessages(agent: agent, appMessages: messages)
        let agentKey = agent.apiKey
        let agentBaseURL = agent.baseURL

        let requestBody = ChatCompletionRequest(
            model: agent.model,
            messages: apiMessages,
            enableSearch: agent.enableSearch,
            enableThinking: agent.enableThinking,
            stream: true
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if agentBaseURL.contains("xiaomimimo.com") {
            request.setValue(agentKey, forHTTPHeaderField: "api-key")
        } else {
            request.setValue("Bearer \(agentKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 120

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw APIError.encodingFailed(error)
        }

        let (bytes, httpResponse) = try await URLSession.shared.bytes(for: request)

        guard let response = httpResponse as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= response.statusCode else {
            var bodyData = Data()
            for try await byte in bytes {
                bodyData.append(byte)
                if bodyData.count > 2000 { break }
            }
            let body = String(data: bodyData, encoding: .utf8) ?? "无响应体"
            throw APIError.httpError(response.statusCode, body)
        }

        // OpenAI / SSE: events are separated by a blank line; each event can contain multiple `data:` lines.
        // IMPORTANT: must decode as UTF-8 by line; do NOT cast each byte to Character (breaks Chinese/multi-byte UTF-8).
        var bufferData = Data()
        var eventDataLines: [String] = []

        func flushEventIfNeeded() {
            guard !eventDataLines.isEmpty else { return }
            defer { eventDataLines.removeAll(keepingCapacity: true) }

            // Join multi-line data payload (spec: join with \n). Most providers send single-line JSON.
            let payload = eventDataLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !payload.isEmpty else { return }
            guard payload != "[DONE]" else { return }

            if let jsonData = payload.data(using: .utf8),
               let chunk = try? JSONDecoder().decode(ChatStreamChunk.self, from: jsonData),
               let choice = chunk.choices.first {
                let content = choice.delta.content
                let reasoning = choice.delta.reasoning_content
                if content != nil || reasoning != nil {
                    onChunk(content, reasoning)
                }
            }
        }

        for try await byte in bytes {
            bufferData.append(byte)

            while let newlineIndex = bufferData.firstIndex(of: 0x0A) { // \n
                let lineData = bufferData[..<newlineIndex]
                bufferData.removeSubrange(...newlineIndex)

                // Handle CRLF
                let cleanedLineData: Data
                if lineData.last == 0x0D { // \r
                    cleanedLineData = Data(lineData.dropLast())
                } else {
                    cleanedLineData = Data(lineData)
                }

                guard let line = String(data: cleanedLineData, encoding: .utf8) else { continue }
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                // blank line -> end of event
                if trimmed.isEmpty {
                    flushEventIfNeeded()
                    continue
                }

                // Ignore non-data SSE fields (event:, id:, retry:)
                if trimmed.hasPrefix("data:") {
                    var dataPart = String(trimmed.dropFirst("data:".count))
                    if dataPart.hasPrefix(" ") { dataPart.removeFirst() }
                    eventDataLines.append(dataPart)
                }
            }
        }
        // Stream ended without trailing blank line
        flushEventIfNeeded()
    }

    // MARK: - 构建 API 消息

    private func buildAPIMessages(agent: Agent, appMessages: [Message]) -> [APIMessage] {
        var apiMessages: [APIMessage] = []

        apiMessages.append(APIMessage(role: "system", text: agent.systemPrompt))

        for msg in appMessages {
            if msg.isUser {
                if !msg.imageURLs.isEmpty {
                    apiMessages.append(APIMessage(
                        role: "user",
                        imageURLs: msg.imageURLs,
                        text: msg.text.isEmpty ? nil : msg.text,
                        reasoningContent: nil
                    ))
                } else {
                    apiMessages.append(APIMessage(role: "user", text: msg.text))
                }
            } else {
                apiMessages.append(APIMessage(
                    role: "assistant",
                    text: msg.text,
                    reasoningContent: msg.reasoningContent
                ))
            }
        }

        return apiMessages
    }

    // MARK: - 认证头处理

    private func authHeaderName(for agent: Agent) -> String {
        if agent.baseURL.contains("xiaomimimo.com") {
            return "api-key"
        }
        return "Authorization"
    }

    private func authHeaderValue(for agent: Agent) -> String {
        if agent.baseURL.contains("xiaomimimo.com") {
            return agent.apiKey
        }
        return "Bearer \(agent.apiKey)"
    }

    // MARK: - 错误类型

    enum APIError: LocalizedError {
        case invalidURL
        case encodingFailed(Error)
        case invalidResponse
        case httpError(Int, String)
        case serverError(String)
        case emptyResponse
        case decodingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的API地址"
            case .encodingFailed(let e): return "请求体编码失败：\(e.localizedDescription)"
            case .invalidResponse: return "无效的服务器响应"
            case .httpError(let code, let body): return "API请求失败（\(code)）：\(body.prefix(200))"
            case .serverError(let msg): return "API错误：\(msg)"
            case .emptyResponse: return "API返回空响应"
            case .decodingFailed(let e): return "响应解析失败：\(e.localizedDescription)"
            }
        }
    }
}
