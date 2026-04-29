import Foundation

struct ChatThread: Identifiable {
    let id: UUID
    var createdAt: Date
    var title: String
    var messages: [[String: Any]]
}

extension ChatThread {
    var persistenceDict: [String: Any] {
        [
            "id": id.uuidString,
            "createdAt": createdAt.timeIntervalSince1970,
            "title": title,
            "messages": messages
        ]
    }

    static func fromDict(_ dict: [String: Any]) -> ChatThread? {
        guard
            let idStr = dict["id"] as? String,
            let id = UUID(uuidString: idStr),
            let createdAtTs = dict["createdAt"] as? TimeInterval,
            let title = dict["title"] as? String,
            let messages = dict["messages"] as? [[String: Any]]
        else { return nil }

        return ChatThread(
            id: id,
            createdAt: Date(timeIntervalSince1970: createdAtTs),
            title: title,
            messages: messages
        )
    }
}

