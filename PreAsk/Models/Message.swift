import Foundation
import Combine

enum MessageType {
    case normal(isUser: Bool)
    case error
}

class Message: ObservableObject, Identifiable {
    let id = UUID()
    @Published var text: String
    let type: MessageType
    @Published var reasoningContent: String?
    let imageURLs: [String]

    var isUser: Bool {
        if case .normal(let isUser) = type { return isUser }
        return false
    }

    init(text: String, isUser: Bool, reasoningContent: String? = nil, imageURLs: [String] = []) {
        self.text = text
        self.type = .normal(isUser: isUser)
        self.reasoningContent = reasoningContent
        self.imageURLs = imageURLs
    }

    init(errorText: String) {
        self.text = errorText
        self.type = .error
        self.reasoningContent = nil
        self.imageURLs = []
    }

    // MARK: - 持久化辅助

    var persistenceDict: [String: Any] {
        var dict: [String: Any] = [
            "text": text,
            "isUser": isUser,
        ]
        if let rc = reasoningContent {
            dict["reasoningContent"] = rc
        }
        if !imageURLs.isEmpty {
            dict["imageURLs"] = imageURLs
        }
        return dict
    }

    static func fromDict(_ dict: [String: Any]) -> Message? {
        guard let text = dict["text"] as? String else { return nil }
        if let isUser = dict["isUser"] as? Bool {
            var imageURLs: [String] = []
            if let urls = dict["imageURLs"] as? [String] {
                imageURLs = urls
            } else if let single = dict["imageURL"] as? String {
                imageURLs = [single]
            }
            return Message(
                text: text,
                isUser: isUser,
                reasoningContent: dict["reasoningContent"] as? String,
                imageURLs: imageURLs
            )
        } else {
            return Message(errorText: text)
        }
    }
}
