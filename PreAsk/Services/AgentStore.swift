import Foundation
import Combine
import SwiftUI

class AgentStore: ObservableObject {
    static let shared = AgentStore()

    @Published var agents: [Agent] = [] {
        didSet { save() }
    }

    private let storageKey = "com.preask.agents"

    private init() {
        load()
        print("[AgentStore] loaded \(agents.count) agents from storage")
        if agents.isEmpty {
            agents = [Agent.defaultAgent]
            print("[AgentStore] added default agent: \(agents[0].name)")
        }
    }

    var enabledAgents: [Agent] {
        let enabled = agents.filter { $0.isEnabled }
        print("[AgentStore] enabledAgents: \(enabled.count) of \(agents.count)")
        return enabled
    }

    func add(_ agent: Agent) {
        agents.append(agent)
    }

    func update(_ agent: Agent) {
        if let index = agents.firstIndex(where: { $0.id == agent.id }) {
            agents[index] = agent
        }
    }

    func delete(at offsets: IndexSet) {
        agents.remove(atOffsets: offsets)
    }

    func delete(_ agent: Agent) {
        agents.removeAll { $0.id == agent.id }
    }

    // MARK: - 持久化

    private func save() {
        if let data = try? JSONEncoder().encode(agents) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Agent].self, from: data) else {
            return
        }
        agents = decoded
    }
}
