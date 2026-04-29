import SwiftUI
import PhotosUI
import Combine

struct ContentView: View {
    @State private var bootDone = false
    @State private var showSettings = false
    @State private var showAgentList = false
    @State private var showHistoryDrawer = false
    @GestureState private var drawerDragX: CGFloat = 0

    @ObservedObject private var agentStore = AgentStore.shared
    @StateObject private var chatStore = ChatStore()
    @State private var selectedAgentIndex = 0
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var isTTSMode = false
    @FocusState private var isInputFocused: Bool
    @ObservedObject private var net = NetworkMonitor.shared
    @ObservedObject private var ttsStore = TTSStore.shared
    @ObservedObject private var audioPlayer = AudioPlayerManager.shared

    @State private var attachedImages: [PhotosPickerItem] = []
    @State private var attachedImageURLs: [String] = []
    @State private var attachedImageDatas: [Data] = []
    @State private var showReasoningMap: Set<UUID> = []
    @State private var voiceOutputEnabled = true

    @State private var heroWaveHeights: [CGFloat] = []
    @State private var bootWaveHeights: [CGFloat] = []
    @State private var isKeyboardActive = false
    @State private var darkHeaderContentHeight: CGFloat = 260
    
    // 图片缓存
    fileprivate static var imageCache: [String: UIImage] = [:]

    var body: some View {
        ZStack {
            mainContent
            if !bootDone {
                BootSequenceView(hasCompleted: $bootDone, waveHeights: bootWaveHeights)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            heroWaveHeights = Theme.stableWaveHeights(count: 60, min: 4, max: 28, seed: 7)
            bootWaveHeights = Theme.stableWaveHeights(count: 50, min: 3, max: 20, seed: 13)
        }
    }

    // MARK: - 主界面

    private var mainContent: some View {
        NavigationStack {
            GeometryReader { geo in
                let drawerWidth = geo.size.width * 0.72
                let effectiveDrag = max(0, min(drawerDragX, drawerWidth))
                let mainOffsetX = (showHistoryDrawer ? drawerWidth : 0) + effectiveDrag

                ZStack(alignment: .leading) {
                    // Drawer background layer
                    Theme.background.ignoresSafeArea()

                    // Drawer is always in hierarchy; slide with mainOffset to look like "revealed"
                    historyDrawer(width: drawerWidth)
                        .frame(width: drawerWidth)
                        .offset(x: -drawerWidth + mainOffsetX)

                    // Main content
                    ZStack(alignment: .top) {
                        Theme.background.ignoresSafeArea()

                        VStack(spacing: 0) {
                            darkHeroSection
                            
                            Rectangle()
                                .fill(Theme.red)
                                .frame(height: 3)
                            
                            agentBar

                            if let session = currentSession, !session.messages.isEmpty {
                                ChatSessionMessagesView(
                                    session: session,
                                    isTyping: $isTyping,
                                    selectedAgentName: selectedAgentName,
                                    showReasoningMap: $showReasoningMap
                                )
                            } else {
                                emptyState
                            }

                            inputPanel
                        }

                        if isTTSMode && !ttsStore.config.isConfigured {
                            ttsConfigBanner
                        }
                    }
                    .compositingGroup()
                    .offset(x: mainOffsetX)
                    .gesture(
                        DragGesture(minimumDistance: 12, coordinateSpace: .local)
                            .onEnded { value in
                                let base = showHistoryDrawer ? drawerWidth : 0
                                let final = min(max(base + value.translation.width, 0), drawerWidth)
                                let shouldOpen = final > drawerWidth * 0.28
                                withAnimation(.spring(response: 0.33, dampingFraction: 0.86)) {
                                    showHistoryDrawer = shouldOpen
                                }
                            }
                            .updating($drawerDragX) { value, state, _ in
                                let base: CGFloat = showHistoryDrawer ? drawerWidth : 0
                                let proposed = base + value.translation.width
                                state = min(max(proposed, 0), drawerWidth) - base
                            }
                    )
                }
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
                .toolbar(.hidden)
                .statusBarHidden(isKeyboardActive)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showAgentList) { AgentListView() }
        .onAppear {
            chatStore.sync(with: agentStore.enabledAgents)

            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil, queue: .main
            ) { _ in
                isKeyboardActive = true
            }
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil, queue: .main
            ) { _ in
                isKeyboardActive = false
            }
        }
        .onChange(of: agentStore.agents.count) { _, _ in
            chatStore.sync(with: agentStore.enabledAgents)
        }
        .onChange(of: attachedImages) { _, newItems in
            Task {
                var datas: [Data] = []
                var urls: [String] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        datas.append(data)
                        urls.append("data:image/jpeg;base64,\(data.base64EncodedString())")
                    }
                }
                await MainActor.run {
                    attachedImageDatas = datas
                    attachedImageURLs = urls
                }
            }
        }
    }

    // MARK: - TTS 未配置提示

    private var ttsConfigBanner: some View {
        VStack {
            HStack(spacing: 8) {
                Circle().fill(Theme.red).frame(width: 6, height: 6)
                Text("TTS 未配置 — 请在 Settings 中设置 Mimo API Key")
                    .font(Theme.caption(12))
                    .foregroundColor(Theme.red.opacity(0.9))
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Text("设置")
                        .font(Theme.caption(12).weight(.semibold))
                        .foregroundColor(Theme.red)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Theme.surface)
            Spacer()
        }
    }

    // MARK: - 深色头部

    private var darkHeroSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(alignment: .center, spacing: 4) {
                    Text("PreAsk")
                        .font(Theme.display(36))
                        .foregroundColor(Theme.textOnDark)

                    Circle()
                        .fill(Theme.red)
                        .frame(width: 20, height: 20)
                        .opacity(isTyping ? 0.3 : 1)
                        .scaleEffect(isTyping ? 0.9 : 1.1)
                        .animation(
                            Animation.easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true),
                            value: isTyping
                        )
                        .padding(.leading, 6)
                    }
                Spacer()
            }
            .padding(.horizontal, 16)

            audioWaveform


            HStack {
                Button {
                    showAgentList = true
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedAgentName)
                            .font(Theme.subheading(18))
                            .foregroundColor(Theme.textOnDark)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textOnDark.opacity(0.5))
                    }
                }

                Spacer()

                if let agent = currentAgentFromStore, !isTTSMode {
                    HStack(spacing: 6) {
                        featureToggle(
                            icon: "globe",
                            isOn: agent.enableSearch,
                            label: "搜索",
                            action: { toggleSearch() }
                        )
                        featureToggle(
                            icon: "brain.head.profile",
                            isOn: agent.enableThinking,
                            label: "思考",
                            action: { toggleThinking() }
                        )
                        featureToggle(
                            icon: "speaker.wave.2.fill",
                            isOn: voiceOutputEnabled && ttsStore.config.isConfigured,
                            label: "语音",
                            action: { toggleVoiceOutput() }
                        )
                    }
                }

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Theme.textOnDark.opacity(0.6))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Theme.graySection)
        }
        .background(Theme.darkSection)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        darkHeaderContentHeight = geo.size.height
                    }
            }
        )
    }
    
    // MARK: - 声波可视化
    private var audioWaveform: some View {
        let dotRadius: CGFloat = 1.5
        let dotCount = AudioPlayerManager.waveDotCount
        let holdDuration = AudioPlayerManager.waveHoldDuration

        return TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let waveData = audioPlayer.waveSamples
            let activated = audioPlayer.waveActivated
            let isActive = !waveData.isEmpty

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let maxExpand = h * 0.8
                let spacing = (w - CGFloat(dotCount) * dotRadius * 2) / CGFloat(max(1, dotCount - 1))

                HStack(spacing: spacing) {
                    ForEach(0..<dotCount, id: \.self) { i in
                        let normalizedPos = CGFloat(i) / CGFloat(max(1, dotCount - 1))

                        let activatedAt = i < activated.count ? activated[i] : -1.0
                        let timeSinceActivation = activatedAt > 0 ? now - activatedAt : holdDuration + 1
                        let isHolding = timeSinceActivation <= holdDuration
                        let holdSeconds = 1.0
                        let fadeFactor: CGFloat = timeSinceActivation <= holdSeconds
                            ? 1.0
                            : max(0, 1.0 - CGFloat((timeSinceActivation - holdSeconds) / (holdDuration - holdSeconds)))

                        let sampleIdx = isActive
                            ? min(waveData.count - 1, max(0, Int(normalizedPos * CGFloat(waveData.count))))
                            : 0
                        let loudness: CGFloat = isActive ? waveData[sampleIdx] : 0
                        let expandHeight = loudness > 0 ? loudness * maxExpand : dotRadius * 2

                        let pulsePhase = now.truncatingRemainder(dividingBy: 2.0) / 2.0
                        let rawDist = abs(normalizedPos - pulsePhase)
                        let dist = rawDist > 0.5 ? 1.0 - rawDist : rawDist
                        let pulseFade = max(0, 1.0 - dist / 0.25)
                        let idleOpacity = 0.15 + 0.85 * pulseFade

                        if isHolding {
                            let dotColor = Color(
                                red: 0.95 * fadeFactor + 0.15 * (1 - fadeFactor),
                                green: 0.20 * fadeFactor + 0.15 * (1 - fadeFactor),
                                blue: 0.20 * fadeFactor + 0.15 * (1 - fadeFactor)
                            )
                            RoundedRectangle(cornerRadius: dotRadius)
                                .fill(dotColor)
                                .frame(
                                    width: dotRadius * 2,
                                    height: dotRadius * 2 + (expandHeight - dotRadius * 2) * fadeFactor
                                )
                                .opacity(0.3 + 0.7 * fadeFactor)
                        } else {
                            Circle()
                                .fill(Color.white.opacity(idleOpacity))
                                .frame(width: dotRadius * 2, height: dotRadius * 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 90)
        }
    }
    
    // MARK: - 格式化时间
    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite else { return "0:00" }
        let min = Int(t) / 60
        let sec = Int(t) % 60
        return String(format: "%d:%02d", min, sec)
    }

    // MARK: - 功能开关按钮

    private func featureToggle(icon: String, isOn: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isOn ? Theme.red : Theme.textOnDark.opacity(0.4))
                Text(label)
                    .font(Theme.caption(13))
                    .foregroundColor(isOn ? Theme.red : Theme.textOnDark.opacity(0.4))
            }
            .frame(width: 64, height: 28)
            .frame(alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOn ? Theme.red.opacity(0.12) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isOn ? Theme.red.opacity(0.6) : Theme.textOnDark.opacity(0.2), lineWidth: 1.2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var currentAgent: Agent? {
        guard chatStore.sessions.indices.contains(selectedAgentIndex) else { return nil }
        return chatStore.sessions[selectedAgentIndex].agent
    }
    
    private var currentAgentFromStore: Agent? {
        guard chatStore.sessions.indices.contains(selectedAgentIndex) else { return nil }
        let agentID = chatStore.sessions[selectedAgentIndex].agentID
        return agentStore.agents.first { $0.id == agentID }
    }

    private func toggleSearch() {
        guard let agent = currentAgentFromStore,
              let idx = agentStore.agents.firstIndex(where: { $0.id == agent.id }) else { return }
        agentStore.agents[idx].enableSearch.toggle()
        chatStore.sync(with: agentStore.enabledAgents)
    }

    private func toggleThinking() {
        guard let agent = currentAgentFromStore,
              let idx = agentStore.agents.firstIndex(where: { $0.id == agent.id }) else { return }
        agentStore.agents[idx].enableThinking.toggle()
        chatStore.sync(with: agentStore.enabledAgents)
    }

    private func toggleVoiceOutput() {
        voiceOutputEnabled.toggle()
    }

    private var selectedAgentName: String {
        chatStore.sessions.indices.contains(selectedAgentIndex)
            ? chatStore.sessions[selectedAgentIndex].agent.name
            : "PreAsk"
    }

    // MARK: - Agent 标签条

    private var agentBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(Array(chatStore.sessions.enumerated()), id: \.element.id) { index, session in
                    let isSelected = index == selectedAgentIndex
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedAgentIndex = index
                        }
                    } label: {
                        VStack(alignment: .center, spacing: 4) {
                            HStack(alignment: .top, spacing: 3) {
                                Text(session.agent.name)
                                    .font(Theme.bodyBold(18))
                                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                                    .offset(y: 0.5)
                            }
                            
                            if isSelected {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.red)
                                    .frame(height: 4)
                                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                                    .offset(y: -1.5)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.surface)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedAgentIndex)
    }

    // MARK: - 消息区域

    // 说明：消息列表必须显式观察 ChatSession（否则 session.messages 的变化可能不会触发 ContentView 刷新）
    private struct ChatSessionMessagesView: View {
        @ObservedObject var session: ChatSession
        @Binding var isTyping: Bool
        let selectedAgentName: String
        @Binding var showReasoningMap: Set<UUID>
        @State private var lastScrolledMessageID: UUID?

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(session.messages) { message in
                            MessageRowView(
                                message: message,
                                selectedAgentName: selectedAgentName,
                                showReasoningMap: $showReasoningMap
                            )
                                .id(message.id)
                        }

                        if session.isLoading {
                            HStack(spacing: 10) {
                                Text("Thinking...")
                                    .font(Theme.body(14))
                                    .foregroundColor(Theme.textSecondary)
                                Circle()
                                    .fill(Theme.red)
                                    .frame(width: 7, height: 7)
                                    .opacity(isTyping ? 1 : 0.35)
                                    .scaleEffect(isTyping ? 1 : 0.6)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(), value: isTyping)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                .onAppear {
                    scrollToBottomIfNeeded(proxy: proxy, animated: false, force: true)
                }
                .onChange(of: session.messages.count) { _, _ in
                    scrollToBottomIfNeeded(proxy: proxy, animated: true, force: true)
                }
                // 流式输出会频繁更新最后一条消息文本；节流滚动，避免定时器导致的卡顿
                .onReceive(
                    session.objectWillChange
                        .debounce(for: .milliseconds(140), scheduler: RunLoop.main)
                ) { _ in
                    guard session.isLoading else { return }
                    scrollToBottomIfNeeded(proxy: proxy, animated: false, force: false)
                }
            }
        }

        private func scrollToBottomIfNeeded(proxy: ScrollViewProxy, animated: Bool, force: Bool) {
            guard let last = session.messages.last else { return }
            if !force, lastScrolledMessageID == last.id { return }
            lastScrolledMessageID = last.id

            DispatchQueue.main.async {
                if animated {
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                } else {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("04/29")
                    .font(Theme.giantNumber(96))
                    .foregroundColor(Theme.divider.opacity(0.8))

                Rectangle()
                    .fill(Theme.red)
                    .frame(width: 3, height: 36)
                    .cornerRadius(1.5)

                VStack(spacing: 8) {
                    Text(isTTSMode ? "Type text to synthesize" : "Send a message")
                        .font(Theme.body(18))
                        .foregroundColor(Theme.textMuted)
                    Text(isTTSMode ? "voice cloning via Mimo" : "to start a conversation")
                        .font(Theme.caption(13))
                        .foregroundColor(Theme.textMuted.opacity(0.7))
                }
            }

            Spacer()
        }
    }



    // MARK: - 输入面板

    private var inputPanel: some View {
        VStack(spacing: 0) {
            chatActionBar

            if !attachedImageDatas.isEmpty {
                attachedImageBar
            }

            Rectangle()
                .fill(Theme.divider)
                .frame(height: 0.5)

            HStack(spacing: 6) {
                ttsModeToggle

                ZStack(alignment: .trailing) {
                    ZStack(alignment: .leading) {
                        if inputText.isEmpty {
                            Text(placeholderText)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, isTTSMode ? 8 : 12)
                                .padding(.vertical, 8)
                        }
                        TextField("", text: $inputText)
                            .font(Theme.body(18))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, isTTSMode ? 6 : 10)
                            .padding(.vertical, 8)
                            .focused($isInputFocused)
                            .tint(Theme.red)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isInputFocused = true
                    }
                }
                .animation(.easeOut(duration: 0.15), value: inputText.isEmpty)

                if !isTTSMode {
                    PhotosPicker(selection: $attachedImages, maxSelectionCount: 9, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.rSmall)
                                .stroke(!attachedImageDatas.isEmpty ? Theme.red : Theme.textSecondary.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.rSmall)
                                        .fill(!attachedImageDatas.isEmpty ? Theme.red.opacity(0.1) : Color.clear)
                                )

                            Image(systemName: "photo")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(!attachedImageDatas.isEmpty ? Theme.red : Theme.textSecondary.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button(action: send) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.rSmall)
                            .fill(canSend ? (isTTSMode ? Theme.red : Theme.darkSection) : Theme.textSecondary.opacity(0.4))
                            .frame(width: 36, height: 36)

                        if isTTSMode {
                            Image(systemName: "waveform")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(!canSend)
                .animation(.easeOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = true
            }
        }
    }

    private var chatActionBar: some View {
        HStack(spacing: 6) {
            actionPillButton(
                title: "New Chat",
                systemImage: "plus.message"
            ) {
                startNewChat()
            }

            actionPillButton(
                title: "History",
                systemImage: "clock.arrow.circlepath"
            ) {
                toggleDrawer()
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.surface)
    }

    private func actionPillButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(Theme.caption(13).weight(.semibold))
            }
            .foregroundColor(Theme.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.red.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.red.opacity(0.35), lineWidth: 1)
                    )
            )
        }
    }

    private func toggleDrawer() {
        dismissKeyboard()
        withAnimation(.spring(response: 0.33, dampingFraction: 0.86)) {
            showHistoryDrawer.toggle()
        }
    }

    private func closeDrawer() {
        withAnimation(.spring(response: 0.33, dampingFraction: 0.86)) {
            showHistoryDrawer = false
        }
    }

    private func startNewChat() {
        guard let session = currentSession else { return }
        dismissKeyboard()
        // 保存当前线程快照后，新建一个 thread 并切换到空聊天
        chatStore.save()
        chatStore.createNewThread(for: session.agentID)
        session.restoreMessages(from: [])
        isTyping = false
        closeDrawer()
    }

    private func historyDrawer(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(Theme.subheading(18))
                        .foregroundColor(Theme.textPrimary)
                    Text(selectedAgentName)
                        .font(Theme.caption(12))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Button {
                    closeDrawer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.surfaceAlt)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Rectangle()
                .fill(Theme.divider)
                .frame(height: 0.5)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(currentThreads) { thread in
                        historyRow(thread: thread, width: width)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .overlay(
            Rectangle()
                .fill(Theme.divider)
                .frame(width: 0.5),
            alignment: .trailing
        )
    }

    private var currentThreads: [ChatThread] {
        guard let session = currentSession else { return [] }
        return chatStore.threadsByAgentID[session.agentID] ?? []
    }

    private func historyRow(thread: ChatThread, width: CGFloat) -> some View {
        let isSelected = (currentSession?.agentID).flatMap { chatStore.selectedThreadIDByAgentID[$0] } == thread.id

        return Button {
            selectThread(thread)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(thread.title.isEmpty ? "Chat" : thread.title)
                    .font(Theme.bodyBold(15))
                    .foregroundColor(isSelected ? Theme.red : Theme.textPrimary)
                    .lineLimit(2)
                Text(thread.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.caption(11))
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Theme.red.opacity(0.10) : Theme.surfaceAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Theme.red.opacity(0.35) : Theme.divider.opacity(0.8), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func selectThread(_ thread: ChatThread) {
        guard let session = currentSession else { return }
        // 切换前写回当前 thread
        chatStore.save()
        chatStore.selectThread(agentID: session.agentID, threadID: thread.id)
        session.restoreMessages(from: thread.messages)
        isTyping = false
        closeDrawer()
    }

    // MARK: - 已附加图片栏

    private var attachedImageBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(attachedImageDatas.enumerated()), id: \.offset) { index, data in
                    if let uiImage = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Button {
                                attachedImages.remove(at: index)
                                attachedImageDatas.remove(at: index)
                                attachedImageURLs.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.textMuted)
                                    .background(Circle().fill(Theme.surface))
                            }
                            .offset(x: 4, y: -4)
                        }
                    }
                }
                
                Text("\(attachedImageDatas.count) 张图片已附加")
                    .font(Theme.caption(13))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Theme.surfaceAlt)
    }

    // MARK: - TTS 模式切换按钮

    private var ttsModeToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isTTSMode.toggle()
                if isTTSMode { audioPlayer.stop() }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.rSmall)
                    .stroke(isTTSMode ? Theme.red : Theme.divider, lineWidth: 1.5)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.rSmall)
                            .fill(isTTSMode ? Theme.red.opacity(0.1) : Color.clear)
                    )

                Image(systemName: "mic.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isTTSMode ? Theme.red : Theme.textMuted)
            }
        }
        .buttonStyle(.plain)
    }

    private var placeholderText: String {
        isTTSMode ? "Text to synthesize..." : "Message..."
    }

    // MARK: - 逻辑

    private var currentSession: ChatSession? {
        chatStore.sessions.indices.contains(selectedAgentIndex)
            ? chatStore.sessions[selectedAgentIndex] : nil
    }

    private var canSend: Bool {
        let hasContent = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachedImageDatas.isEmpty
        guard hasContent, !isTyping, net.apiReachable else { return false }
        if isTTSMode {
            return ttsStore.config.isConfigured
        } else {
            return !chatStore.sessions.isEmpty
        }
    }

    private func dismissKeyboard() {
        isInputFocused = false
    }

    private func send() {
        guard canSend else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageURLs = attachedImageURLs
        inputText = ""
        attachedImages = []
        attachedImageDatas = []
        attachedImageURLs = []
        isTyping = true
        dismissKeyboard()

        if isTTSMode {
            sendTTS(text: text)
        } else {
            sendChat(text: text, imageURLs: imageURLs)
        }
    }

    private func sendChat(text: String, imageURLs: [String]) {
        Task {
            var aiIndices: [Int] = []
            await MainActor.run {
                for s in chatStore.sessions {
                    let aiIndex = s.addUserMessageAndStartLoading(text: text, imageURLs: imageURLs)
                    aiIndices.append(aiIndex)
                }
            }
            
            await withTaskGroup(of: Void.self) { group in
                for (index, s) in chatStore.sessions.enumerated() {
                    let aiIndex = aiIndices[index]
                    group.addTask {
                        await s.sendToAPIAfterUserMessage(aiIndex: aiIndex, text: text, imageURLs: imageURLs)
                    }
                }
            }
            
            await MainActor.run {
                isTyping = false
                chatStore.save()

                if voiceOutputEnabled, ttsStore.config.isConfigured,
                   let lastMsg = currentSession?.messages.last,
                   !lastMsg.isUser, !lastMsg.text.isEmpty {
                    synthesizeLastResponse(lastMsg.text)
                }
            }
        }
    }

    private func synthesizeLastResponse(_ text: String) {
        audioPlayer.setLoading()
        Task {
            do {
                let audioData = try await TTSService.shared.synthesize(text: text)
                await MainActor.run {
                    audioPlayer.load(audioData: audioData, text: text)
                    audioPlayer.play()
                }
            } catch {
                await MainActor.run {
                    audioPlayer.setError(error.localizedDescription)
                }
            }
        }
    }

    private func sendTTS(text: String) {
        audioPlayer.setLoading()

        guard let session = currentSession else {
            isTyping = false
            return
        }

        session.addMessage(Message(text: text, isUser: true))

        Task {
            do {
                let audioData = try await TTSService.shared.synthesize(text: text)
                await MainActor.run {
                    audioPlayer.load(audioData: audioData, text: text)
                    audioPlayer.play()
                    isTyping = false
                }
            } catch {
                await MainActor.run {
                    audioPlayer.setError(error.localizedDescription)
                    session.addMessage(Message(errorText: "TTS: \(error.localizedDescription)"))
                    isTyping = false
                }
            }
        }
    }
}

// MARK: - MessageRowView

struct MessageRowView: View {
    @ObservedObject var message: Message
    let selectedAgentName: String
    @Binding var showReasoningMap: Set<UUID>
    
    var body: some View {
        Group {
            if message.isUser {
                userMessageView
            } else {
                agentMessageView
            }
        }
    }
    
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: 6) {
                    if !message.imageURLs.isEmpty {
                        ForEach(Array(message.imageURLs.enumerated()), id: \.offset) { _, imageURL in
                            if imageURL.hasPrefix("data:") {
                                imagePreview(dataURL: imageURL)
                                    .id(message.id)
                            }
                        }
                    }
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(Theme.body(18))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.rMini)
                                    .fill(Theme.darkSection)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .id("user-\(message.id)")
    }
    
    private var agentMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.red)
                            .frame(width: 7, height: 7)
                        Text(selectedAgentName)
                            .font(Theme.caption(13))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Rectangle()
                        .fill(Theme.textMuted)
                        .frame(height: 1)
                    reasoningToggleButton
                }
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.red)
                        .frame(width: 7, height: 7)
                    Text(selectedAgentName)
                        .font(Theme.caption(13))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
            }

            if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                reasoningBubble
            }

            if !message.text.isEmpty {
                Text(message.text)
                    .font(.system(size: 18, weight: .regular, design: .default))
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(5)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
        .id("agent-\(message.id)")
    }
    
    private var reasoningToggleButton: some View {
        let isExpanded = showReasoningMap.contains(message.id)
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0)) {
                if isExpanded {
                    showReasoningMap.remove(message.id)
                } else {
                    showReasoningMap.insert(message.id)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                Text(isExpanded ? "收起思考" : "查看思考过程")
                    .font(Theme.caption(12))
                    .foregroundColor(Theme.textSecondary)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var reasoningBubble: some View {
        let isExpanded = showReasoningMap.contains(message.id)
        return Group {
            if isExpanded, let reasoning = message.reasoningContent {
                VStack(spacing: 0) {
                    Text(reasoning)
                        .font(Theme.caption(13))
                        .foregroundColor(Theme.textSecondary)
                        .lineSpacing(4)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .top)
                            .combined(with: .opacity)
                            .combined(with: .offset(y: -8)),
                        removal: .scale(scale: 0.98, anchor: .top)
                            .combined(with: .opacity)
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: Theme.rMini)
                        .fill(Theme.surface)
                )
            }
        }
    }
    
    private func imagePreview(dataURL: String) -> some View {
        Group {
            if let uiImage = ContentView.imageCache[dataURL] {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rMedium))
            } else if let commaIdx = dataURL.firstIndex(of: ",") {
                let base64 = String(dataURL[dataURL.index(after: commaIdx)...])
                if let data = Data(base64Encoded: base64),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rMedium))
                        .onAppear {
                            ContentView.imageCache[dataURL] = uiImage
                        }
                }
            }
        }
    }
}

#Preview { ContentView() }
