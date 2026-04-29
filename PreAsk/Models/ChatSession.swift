import Foundation
import Combine

class ChatSession: ObservableObject, Identifiable {
    let id = UUID()
    var agent: Agent
    var agentID: UUID { agent.id }
    @Published var messages: [Message] = []
    @Published var isLoading = false

    private var reasoningMap: [UUID: String] = [:]
    // 用于跟踪消息变化的 Cancellable
    private var messageCancellables = [UUID: AnyCancellable]()

    init(agent: Agent) {
        self.agent = agent
    }
    
    func updateAgent(_ newAgent: Agent) {
        self.agent = newAgent
    }

    func restoreMessages(from data: [[String: Any]]) {
        messages = data.compactMap { Message.fromDict($0) }
        // 监听所有历史消息的变化
        messageCancellables.removeAll()
        for message in messages {
            observeMessage(message)
        }
    }

    @MainActor
    func addUserMessageAndStartLoading(text: String, imageURLs: [String] = []) -> Int {
        let userMessage = Message(text: text, isUser: true, imageURLs: imageURLs)
        let aiMessage = Message(text: "", isUser: false)
        
        isLoading = true
        messages.append(userMessage)
        messages.append(aiMessage)
        
        // 监听新添加的消息变化
        observeMessage(userMessage)
        observeMessage(aiMessage)
        
        return messages.count - 1
    }
    
    // 辅助方法：监听消息变化
    private func observeMessage(_ message: Message) {
        messageCancellables[message.id] = message.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    func sendToAPIAfterUserMessage(aiIndex: Int, text: String, imageURLs: [String] = []) async {
        // 注意：这里使用 Array(messages.dropLast()) 确保不包含刚添加的空 AI 消息
        let history = Array(messages.dropLast())

        do {
            try await ChatAPIManager.shared.sendStreamingRequest(
                agent: agent,
                messages: history
            ) { [weak self] content, reasoning in
                guard let self else { return }
                Task { @MainActor in
                    guard self.messages.indices.contains(aiIndex) else { return }
                    if let content {
                        self.messages[aiIndex].text += content
                    }
                    if let reasoning {
                        if let existing = self.messages[aiIndex].reasoningContent {
                            self.messages[aiIndex].reasoningContent = existing + reasoning
                        } else {
                            self.messages[aiIndex].reasoningContent = reasoning
                        }
                    }
                }
            }
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                if messages.indices.contains(aiIndex) && messages[aiIndex].text.isEmpty {
                    messages[aiIndex] = Message(errorText: error.localizedDescription)
                } else {
                    messages.append(Message(errorText: error.localizedDescription))
                }
                isLoading = false
            }
        }
    }

    // 保留旧方法向后兼容
    func sendToAPI(text: String, imageURLs: [String] = []) async {
        let aiIndex = await addUserMessageAndStartLoading(text: text, imageURLs: imageURLs)
        await sendToAPIAfterUserMessage(aiIndex: aiIndex, text: text, imageURLs: imageURLs)
    }

    func addMessage(_ message: Message) {
        messages.append(message)
    }
}
