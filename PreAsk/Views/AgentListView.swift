import SwiftUI

struct AgentListView: View {
    @ObservedObject private var agentStore = AgentStore.shared
    @State private var showAddAgent = false
    @State private var editingAgent: Agent?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose Agent")
                                .font(Theme.heading(28))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(Theme.textMuted)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                    .padding(.bottom, 24)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(agentStore.agents) { agent in
                                Button {
                                    editingAgent = agent
                                } label: {
                                    HStack(alignment: .center, spacing: 16) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(agent.name)
                                                .font(Theme.subheading(22))
                                                .foregroundColor(Theme.textPrimary)
                                            Text(agent.model)
                                                .font(Theme.caption(16))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Spacer()
                                        HStack(alignment: .center, spacing: 6) {
                                            Text(agent.isEnabled ? "ON" : "OFF")
                                                .font(Theme.caption(20))
                                                .foregroundColor(agent.isEnabled ? Theme.red : Theme.textMuted)
                                            Circle()
                                                .fill(agent.isEnabled ? Theme.red : Theme.divider)
                                                .frame(width: 12, height: 12)
                                        }
                                    }
                                    .padding(.vertical, 18)
                                    .padding(.horizontal, 20)
                                    .background(Theme.surface)
                                    .cornerRadius(Theme.rMedium)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total")
                                .font(Theme.caption(20))
                                .foregroundColor(Theme.textMuted)
                            Text("\(agentStore.agents.count)")
                                .font(Theme.display(80))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        Button(action: { showAddAgent = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(Theme.red)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAddAgent) {
            AgentEditor(agent: nil) { agentStore.add($0) }
        }
        .sheet(item: $editingAgent) { agent in
            AgentEditor(agent: agent) { agentStore.update($0) }
        }
    }
}

#Preview("Agent List") {
    AgentListView()
}
