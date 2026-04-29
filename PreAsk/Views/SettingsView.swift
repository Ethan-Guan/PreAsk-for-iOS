import SwiftUI

struct SettingsView: View {
    @ObservedObject private var agentStore = AgentStore.shared
    @ObservedObject private var ttsStore = TTSStore.shared
    @State private var showingAddAgent = false
    @State private var editingAgent: Agent?
    @State private var showingTTSEditor = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    Spacer()
                    Spacer()
                    VStack(spacing: 16) {
                        // AI Agents
                        VStack(alignment: .leading, spacing: 0) {
                            Text("AI AGENTS")
                                .font(Theme.caption(13))
                                .foregroundColor(Theme.textMuted)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 6)

                            ForEach(agentStore.agents) { agent in
                                Button {
                                    editingAgent = agent
                                } label: {
                                    VStack(spacing: 0) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack(spacing: 8) {
                                                    Circle()
                                                        .fill(agent.apiKey.isEmpty ? Theme.divider : Theme.red)
                                                        .frame(width: 7, height: 7)
                                                    Text(agent.name)
                                                        .font(Theme.subheading(17))
                                                        .foregroundColor(Theme.textPrimary)
                                                }
                                                Text(agent.model)
                                                    .font(Theme.caption(13))
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                            Spacer()
                                            HStack {
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(Theme.textMuted)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        
                                        if agent.id != agentStore.agents.last?.id {
                                            Rectangle()
                                                .fill(Theme.divider)
                                                .frame(height: 0.5)
                                                .padding(.leading, 20)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                showingAddAgent = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Add Agent")
                                        .font(Theme.body(15))
                                }
                                .foregroundColor(Theme.red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                        }
                        .background(Theme.surface)
                        .cornerRadius(Theme.rMedium)

                        // TTS (Mimo Voice Clone)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("TTS")
                                .font(Theme.caption(13))
                                .foregroundColor(Theme.textMuted)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 6)

                            Button {
                                showingTTSEditor = true
                            } label: {
                                VStack(spacing: 0) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(ttsStore.config.isConfigured ? Theme.red : Theme.divider)
                                                    .frame(width: 7, height: 7)
                                                Text("Voice Clone")
                                                    .font(Theme.subheading(17))
                                                    .foregroundColor(Theme.textPrimary)
                                            }
                                            Text(ttsStore.config.model)
                                                .font(Theme.caption(13))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Theme.textMuted)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    
                                    if ttsStore.config.isConfigured {
                                        Rectangle()
                                            .fill(Theme.divider)
                                            .frame(height: 0.5)
                                            .padding(.leading, 24)
                                        HStack {
                                            Text("Voice sample")
                                                .font(Theme.caption(12))
                                                .foregroundColor(Theme.textSecondary)
                                            Spacer()
                                            Text("Moss (内置)")
                                                .font(Theme.caption(12))
                                                .foregroundColor(Theme.textMuted)
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 14)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Theme.surface)
                        .cornerRadius(Theme.rMedium)

                        // About
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ABOUT")
                                .font(Theme.caption(13))
                                .foregroundColor(Theme.textMuted)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 6)
                            settingsRow("Version", "v1.1.0")
                            Rectangle()
                                .fill(Theme.divider)
                                .frame(height: 0.5)
                                .padding(.leading, 20)
                            settingsRow("Build", "2026.04")
                                .padding(.bottom, 8)
                        }
                        .background(Theme.surface)
                        .cornerRadius(Theme.rMedium)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.red)
                    }
                }
            }
            .navigationTitle(
                Text("ㅤ⁣ㅤSettings")
            )
        }
        .sheet(isPresented: $showingAddAgent) {
            AgentEditor(agent: nil) { agentStore.add($0) }
        }
        .sheet(item: $editingAgent) { agent in
            AgentEditor(agent: agent) { agentStore.update($0) }
        }
        .sheet(isPresented: $showingTTSEditor) {
            TTSEditorView()
        }
    }

    private func settingsRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.body(16))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(Theme.body(16))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - TTS 编辑器

struct TTSEditorView: View {
    @ObservedObject private var ttsStore = TTSStore.shared
    @State private var apiKey: String
    @State private var styleInstruction: String
    @State private var baseURL: String
    @State private var model: String
    @Environment(\.dismiss) private var dismiss

    init() {
        let config = TTSStore.shared.config
        _apiKey = State(initialValue: config.apiKey)
        _styleInstruction = State(initialValue: config.styleInstruction)
        _baseURL = State(initialValue: config.baseURL)
        _model = State(initialValue: config.model)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    Spacer()
                    Spacer()
                    VStack(spacing: 0) {
                        VStack(spacing: 20) {
                            formField("BASE URL", $baseURL, placeholder: "https://api.xiaomimimo.com/v1/chat/completions")
                            formField("API KEY", $apiKey, placeholder: "your-api-key")
                            formField("MODEL NAME", $model, placeholder: "mimo-v2.5-tts-voiceclone")
                            formField("STYLE INSTRUCTION （可选）", $styleInstruction, placeholder: "用轻快活泼的语气说话")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("* 使用 Mimo 音色复刻 API，通过内置声音样本合成任意文本语音。")
                            .font(Theme.caption(14))
                            .foregroundColor(Theme.textSecondary)
                        Text("* 声音样本：Moss")
                            .font(Theme.caption(14))
                            .foregroundColor(Theme.textSecondary)
                        Text("* API 文档: https://api.xiaomimimo.com/v1")
                            .font(Theme.caption(14))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 20)
                    
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.body(16))
                        .foregroundColor(Theme.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var config = ttsStore.config
                        config.apiKey = apiKey
                        config.styleInstruction = styleInstruction
                        config.baseURL = baseURL
                        config.model = model
                        ttsStore.config = config
                        dismiss()
                    }
                    .font(Theme.body(16).weight(.semibold))
                    .foregroundColor(apiKey.isEmpty ? Theme.textMuted : Theme.red)
                    .disabled(apiKey.isEmpty)
                }
            }
            .navigationTitle(
                Text("ㅤ⁣ㅤVoice Clone")
            )
        }
    }

    private func formField(_ label: String, _ text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(Theme.caption(13))
                .foregroundColor(Theme.textMuted)
            TextField(placeholder, text: text)
                .font(Theme.body(16))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Theme.surface)
                .cornerRadius(Theme.rSmall)
        }
    }
}

// MARK: - Agent 编辑器

struct AgentEditor: View {
    let agent: Agent?
    let onSave: (Agent) -> Void

    @State private var name: String
    @State private var baseURL: String
    @State private var apiKey: String
    @State private var model: String
    @State private var systemPrompt: String
    @State private var enableSearch: Bool
    @State private var enableThinking: Bool
    @Environment(\.dismiss) private var dismiss

    init(agent: Agent?, onSave: @escaping (Agent) -> Void) {
        self.agent = agent
        self.onSave = onSave
        _name = State(initialValue: agent?.name ?? "")
        _baseURL = State(initialValue: agent?.baseURL ?? "")
        _apiKey = State(initialValue: agent?.apiKey ?? "")
        _model = State(initialValue: agent?.model ?? "")
        _systemPrompt = State(initialValue: agent?.systemPrompt ?? "")
        _enableSearch = State(initialValue: agent?.enableSearch ?? false)
        _enableThinking = State(initialValue: agent?.enableThinking ?? false)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()
                        Spacer()
                        VStack(spacing: 20) {
                            formField("CUSTOM NAME", $name, placeholder: "@MiMo")
                            formField("BASE URL", $baseURL, placeholder: "https://api.xiaomimimo.com/v1/chat/completions")
                            formField("API KEY", $apiKey, placeholder: "your-api-key")
                            formField("MODEL NAME", $model, placeholder: "mimo-v2.5-pro")
                        }
                        .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("FEATURES")
                                    .font(Theme.caption(13))
                                    .foregroundColor(Theme.textMuted)
                                    .padding(.top, 20)
                            }
                            .padding(.bottom, 10)
                            
                            VStack(spacing: 10) {
                                Toggle(isOn: $enableSearch) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "globe")
                                            .font(.system(size: 16))
                                            .foregroundColor(Theme.textSecondary)
                                        Text("联网搜索")
                                            .font(Theme.body(16))
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                }
                                .tint(Theme.red)
                                
                                Toggle(isOn: $enableThinking) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "brain.head.profile")
                                            .font(.system(size: 16))
                                            .foregroundColor(Theme.textSecondary)
                                        Text("思考模式")
                                            .font(Theme.body(16))
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                }
                                .tint(Theme.red)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Theme.surface)
                            .cornerRadius(Theme.rSmall)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("SYSTEM PROMPT")
                                .font(Theme.caption(13))
                                .foregroundColor(Theme.textMuted)
                                .padding(.top, 20)
                            TextEditor(text: $systemPrompt)
                                .font(Theme.body(16))
                                .foregroundColor(Theme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(minHeight: 150)
                                .background(Theme.surface)
                                .cornerRadius(Theme.rSmall)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.body(16))
                        .foregroundColor(Theme.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let updated = Agent(
                            id: agent?.id ?? UUID(),
                            name: name.isEmpty ? "Unnamed" : name,
                            baseURL: baseURL, apiKey: apiKey,
                            model: model, systemPrompt: systemPrompt,
                            isEnabled: agent?.isEnabled ?? true,
                            enableSearch: enableSearch,
                            enableThinking: enableThinking
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .font(Theme.body(16).weight(.semibold))
                    .foregroundColor(name.isEmpty || baseURL.isEmpty ? Theme.textMuted : Theme.red)
                    .disabled(name.isEmpty || baseURL.isEmpty)
                }
            }
            .navigationTitle(
                Text(agent == nil ? "New Agent" : "Edit Agent")
            )
        }
    }

    private func formField(_ label: String, _ text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(Theme.caption(13))
                .foregroundColor(Theme.textMuted)
            TextField(placeholder, text: text)
                .font(Theme.body(16))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Theme.surface)
                .cornerRadius(Theme.rSmall)
        }
    }
}

#Preview("Settings") {
    SettingsView()
}

#Preview("Agent Editor") {
    AgentEditor(agent: Agent.defaultAgent) { _ in }
}

#Preview("TTS Editor") {
    TTSEditorView()
}
