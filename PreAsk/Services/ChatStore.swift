import Foundation
import Combine

class ChatStore: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published private(set) var threadsByAgentID: [UUID: [ChatThread]] = [:]
    @Published private(set) var selectedThreadIDByAgentID: [UUID: UUID] = [:]

    private let storageKey = "com.preask.chatSessions"

    init() {
        load()
    }

    func sync(with agents: [Agent]) {
        print("[ChatStore] sync called with \(agents.count) agents, current sessions: \(sessions.count)")
        // 新增缺失的 session
        for agent in agents {
            if !sessions.contains(where: { $0.agentID == agent.id }) {
                let session = ChatSession(agent: agent)
                sessions.append(session)
            }
        }
        // 移除已禁用的
        sessions.removeAll { session in
            !agents.contains(where: { $0.id == session.agentID })
        }
        // 更新现有 session 的 agent
        for session in sessions {
            if let agent = agents.first(where: { $0.id == session.agentID }) {
                session.updateAgent(agent)
                ensureThreadsExist(for: agent.id)

                let selectedID = selectedThreadIDByAgentID[agent.id] ?? threadsByAgentID[agent.id]?.first?.id
                if let selectedID,
                   let thread = threadsByAgentID[agent.id]?.first(where: { $0.id == selectedID }) {
                    selectedThreadIDByAgentID[agent.id] = selectedID
                    session.restoreMessages(from: thread.messages)
                }
            }
        }
    }

    func save() {
        // 先把当前 UI 展示的 session.messages 写回当前 thread
        for session in sessions {
            upsertCurrentThreadFromSession(session)
        }

        var data: [String: [String: Any]] = [:]
        for (agentID, threads) in threadsByAgentID {
            let selectedID = selectedThreadIDByAgentID[agentID]
            data[agentID.uuidString] = [
                "selectedThreadID": selectedID?.uuidString as Any,
                "threads": threads.map { $0.persistenceDict }
            ]
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
            UserDefaults.standard.set(jsonData, forKey: storageKey)
        }
    }

    func createNewThread(for agentID: UUID) {
        ensureThreadsExist(for: agentID)

        let thread = ChatThread(
            id: UUID(),
            createdAt: Date(),
            title: "New Chat",
            messages: []
        )
        threadsByAgentID[agentID, default: []].insert(thread, at: 0)
        selectedThreadIDByAgentID[agentID] = thread.id
        save()
    }

    func selectThread(agentID: UUID, threadID: UUID) {
        selectedThreadIDByAgentID[agentID] = threadID
        save()
    }

    private func load() {
        // sync() 会在 onAppear 时调用，这里只做基本初始化
        loadThreadsFromPersistence()
    }

    private func ensureThreadsExist(for agentID: UUID) {
        if threadsByAgentID[agentID] == nil {
            threadsByAgentID[agentID] = [
                ChatThread(id: UUID(), createdAt: Date(), title: "Chat", messages: [])
            ]
        }
        if selectedThreadIDByAgentID[agentID] == nil {
            selectedThreadIDByAgentID[agentID] = threadsByAgentID[agentID]?.first?.id
        }
    }

    private func upsertCurrentThreadFromSession(_ session: ChatSession) {
        let agentID = session.agentID
        ensureThreadsExist(for: agentID)

        let selectedID = selectedThreadIDByAgentID[agentID] ?? threadsByAgentID[agentID]?.first?.id
        guard let selectedID else { return }

        let snapshot = session.messages.map { $0.persistenceDict }
        var threads = threadsByAgentID[agentID] ?? []

        if let idx = threads.firstIndex(where: { $0.id == selectedID }) {
            threads[idx].messages = snapshot
            if threads[idx].title == "New Chat" || threads[idx].title == "Chat" {
                threads[idx].title = deriveTitle(from: session.messages) ?? threads[idx].title
            }
        } else {
            let title = deriveTitle(from: session.messages) ?? "Chat"
            threads.insert(ChatThread(id: selectedID, createdAt: Date(), title: title, messages: snapshot), at: 0)
        }

        threadsByAgentID[agentID] = threads
        selectedThreadIDByAgentID[agentID] = selectedID
    }

    private func deriveTitle(from messages: [Message]) -> String? {
        // 取第一条用户消息前 24 字作为标题
        guard let firstUser = messages.first(where: { $0.isUser && !$0.text.isEmpty }) else { return nil }
        let trimmed = firstUser.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(24))
    }

    private func loadThreadsFromPersistence() {
        guard let jsonData = UserDefaults.standard.data(forKey: storageKey),
              let root = try? JSONSerialization.jsonObject(with: jsonData) else {
            return
        }

        // 兼容旧结构：[agentID: [[messageDict]]]
        if let old = root as? [String: [[String: Any]]] {
            for (agentKey, msgs) in old {
                guard let agentID = UUID(uuidString: agentKey) else { continue }
                let thread = ChatThread(id: UUID(), createdAt: Date(), title: deriveTitle(from: msgs) ?? "Chat", messages: msgs)
                threadsByAgentID[agentID] = [thread]
                selectedThreadIDByAgentID[agentID] = thread.id
            }
            return
        }

        // 新结构：[agentID: { selectedThreadID, threads: [...] }]
        guard let dict = root as? [String: [String: Any]] else { return }
        for (agentKey, payload) in dict {
            guard let agentID = UUID(uuidString: agentKey) else { continue }
            let threadsRaw = payload["threads"] as? [[String: Any]] ?? []
            let threads = threadsRaw.compactMap { ChatThread.fromDict($0) }
            threadsByAgentID[agentID] = threads.isEmpty
                ? [ChatThread(id: UUID(), createdAt: Date(), title: "Chat", messages: [])]
                : threads

            if let selectedStr = payload["selectedThreadID"] as? String,
               let selectedID = UUID(uuidString: selectedStr) {
                selectedThreadIDByAgentID[agentID] = selectedID
            } else {
                selectedThreadIDByAgentID[agentID] = threadsByAgentID[agentID]?.first?.id
            }
        }
    }

    private func deriveTitle(from messages: [[String: Any]]) -> String? {
        // 旧存储里只有 text/isUser
        for m in messages {
            if let isUser = m["isUser"] as? Bool, isUser,
               let text = m["text"] as? String {
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return String(t.prefix(24)) }
            }
        }
        return nil
    }
}
