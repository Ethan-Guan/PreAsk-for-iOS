import Foundation

struct Agent: Identifiable, Codable {
    var id = UUID()
    var name: String
    var baseURL: String
    var apiKey: String
    var model: String
    var systemPrompt: String
    var isEnabled: Bool = true
    var enableSearch: Bool = false
    var enableThinking: Bool = false

    static let defaultAgent = Agent(
        name: "@MiMo",
        baseURL: "https://api.xiaomimimo.com/v1/chat/completions",
        apiKey: "",
        model: "mimo-v2.5-pro",
        systemPrompt: """
        你是 MiMo（中文名称也是 MiMo），是小米公司研发的 AI 智能助手。
        回答要求：
        1. 简洁、干练、精确
        2. 直接输出内容，不添加无关格式
        3. 禁止啰嗦、禁止无关内容
        """,
        enableSearch: false,
        enableThinking: false
    )
}
