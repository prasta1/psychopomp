import SwiftUI
import SwiftData

/// The orb home — the app's primary surface. Hold the orb to talk (release to send),
/// or tap to latch hands-free listening. The agent's reply streams as text below it.
/// History, the full transcript, and the keyboard remain reachable.
struct OrbHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HermesConfig.self) private var config

    /// The conversation the orb is currently bound to (continued across turns).
    @State private var conversation: Conversation?
    @State private var viewModel: ChatViewModel?
    @State private var recorder = VoiceRecorder()

    @State private var path: [Conversation] = []
    @State private var liveTranscript = ""
    @State private var isLocked = false
    @State private var pressStartedAt: Date?
    @State private var permissionDenied = false
    @State private var showRecent = false
    @State private var showSettings = false
    @State private var showKeyboard = false
    @State private var keyboardDraft = ""
    @State private var models: [HermesModelInfo] = []
    /// Whether the last Hermes model fetch succeeded (drives the status dot).
    @State private var reachable = false
    @FocusState private var typing: Bool
    /// Icon-button sizes that grow with Dynamic Type so glyphs and hit-targets scale together.
    @ScaledMetric private var iconButtonSize: CGFloat = 38
    @ScaledMetric private var sendButtonSize: CGFloat = 40

    /// Below which a press counts as a "tap" (latch) rather than a "hold" (send).
    private let tapThreshold: TimeInterval = 0.4

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                orbStage
                topBar
            }
            .orbBackground()
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sensoryFeedback(.impact(weight: .medium), trigger: recorder.isRecording)
            .sensoryFeedback(.selection, trigger: isLocked)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Conversation.self) { ChatView(conversation: $0) }
            .sheet(isPresented: $showRecent) {
                RecentSessionsSheet(
                    current: conversation,
                    onSelect: { select($0) },
                    onOpen: { showRecent = false; path.append($0) },
                    onNew: { startNewSession() }
                )
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .task { await loadModels() }
            .onChange(of: recorder.transcript) { _, new in
                if recorder.isRecording { liveTranscript = new }
            }
        }
        .tint(Theme.Color.aura)
    }

    // MARK: - Orb + current turn

    private var orbStage: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer(minLength: 0)
            OrbView(state: orbState, audioLevel: recorder.level)
                .contentShape(Circle())
                .gesture(orbGesture)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(recorder.isRecording
                    ? "Double-tap to send"
                    : "Double-tap to talk, then double-tap again to send")
                .accessibilityAction { toggleTalkForAccessibility() }
            caption
            replyArea
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var caption: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(captionText)
                .font(Theme.Font.sansTitle)
                .foregroundStyle(Theme.Color.textCool)
            if orbState == .idle {
                Text("tap to lock hands-free")
                    .font(Theme.Font.sansCaption)
                    .foregroundStyle(Theme.Color.textCoolFaint)
            }
            if permissionDenied {
                Text("Microphone access is off — enable it in Settings, or use the keyboard.")
                    .font(Theme.Font.sansCaption)
                    .foregroundStyle(Theme.Color.red)
                    .multilineTextAlignment(.center)
            } else if let error = viewModel?.errorMessage {
                Text(error)
                    .font(Theme.Font.sansCaption)
                    .foregroundStyle(Theme.Color.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: orbState)
    }

    @ViewBuilder
    private var replyArea: some View {
        if recorder.isRecording, !liveTranscript.isEmpty {
            Text(liveTranscript)
                .font(Theme.Font.sansBody)
                .foregroundStyle(Theme.Color.textCoolDim)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .transition(.opacity)
        } else if let assistant = latestAssistant, !assistant.text.isEmpty, let convo = conversation {
            Button { path.append(convo) } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(assistant.text)
                        .font(Theme.Font.sansBody)
                        .foregroundStyle(Theme.Color.textCool)
                        .multilineTextAlignment(.leading)
                        .lineLimit(8)
                    ForEach(assistant.orderedToolEvents) { event in
                        toolChip(event)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func toolChip(_ event: ToolEvent) -> some View {
        Text("\u{25B7} \(event.name)\(event.detail.isEmpty ? "" : " \u{00B7} \(event.detail)")")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.aura)
            .lineLimit(1)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(Theme.Color.aura.opacity(0.12), in: Capsule())
    }

    // MARK: - Chrome (status, settings, keyboard, stop, recent)

    private var topBar: some View {
        HStack {
            statusBadge
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(Theme.Color.textCoolDim)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if showKeyboard { keyboardBar }
            bottomDock
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(statusLabel)
                .font(Theme.Font.sansCaption)
                .foregroundStyle(Theme.Color.textCoolDim)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityStatusLabel)
    }

    private var statusLabel: String {
        if config.selectedModel.isEmpty { return "no model" }
        let id = config.selectedModel
        return id.count > 16 ? "…" + id.suffix(14) : id
    }

    private var accessibilityStatusLabel: String {
        if config.useAppleIntelligence && config.appleIntelligenceClient != nil {
            return "Apple Intelligence active."
        }
        return reachable ? "Connected. Model \(config.selectedModel)." : "Not connected."
    }

    /// Green when a provider is ready, dim when Hermes is configured but unconfirmed,
    /// red when nothing is configured.
    private var dotColor: Color {
        if config.useAppleIntelligence {
            return config.appleIntelligenceClient != nil ? Theme.Color.green : Theme.Color.red
        }
        if !config.isConfigured { return Theme.Color.red }
        return reachable ? Theme.Color.green : Theme.Color.textCoolFaint
    }

    private var bottomDock: some View {
        ZStack {
            // History grabber (swipe up / tap).
            VStack(spacing: 6) {
                Capsule().fill(Theme.Color.textCoolFaint).frame(width: 38, height: 4)
                Text("Recent sessions")
                    .font(Theme.Font.sansCaption)
                    .foregroundStyle(Theme.Color.textCoolDim)
            }
            .contentShape(Rectangle())
            .onTapGesture { showRecent = true }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { if $0.translation.height < -20 { showRecent = true } }
            )

            HStack {
                if viewModel?.isStreaming == true {
                    iconButton("stop.fill", tint: Theme.Color.red) { viewModel?.stop() }
                        .accessibilityLabel("Stop")
                } else {
                    Color.clear.frame(width: iconButtonSize, height: iconButtonSize)
                }
                Spacer()
                iconButton("keyboard", tint: Theme.Color.aura) {
                    permissionDenied = false
                    showKeyboard.toggle()
                    typing = showKeyboard
                }
                .accessibilityLabel("Type a message")
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var keyboardBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Type a message…", text: $keyboardDraft, axis: .vertical)
                .focused($typing)
                .font(Theme.Font.sansBody)
                .foregroundStyle(Theme.Color.textCool)
                .tint(Theme.Color.aura)
                .lineLimit(1...4)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            Button {
                sendText(keyboardDraft)
                keyboardDraft = ""
                showKeyboard = false
            } label: {
                Image(systemName: "arrow.up")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.Color.canvas)
                    .frame(width: sendButtonSize, height: sendButtonSize)
                    .background(canSendText ? Theme.Color.aura : Theme.Color.border, in: Circle())
            }
            .disabled(!canSendText)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private func iconButton(_ system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(tint.opacity(0.12), in: Circle())
        }
    }

    // MARK: - State mapping

    private var orbState: OrbState {
        if !config.isConfigured { return .offline }
        if recorder.isRecording { return .listening }
        if viewModel?.isStreaming == true {
            return (latestAssistant?.text.isEmpty == false) ? .speaking : .thinking
        }
        return .idle
    }

    private var captionText: String {
        switch orbState {
        case .idle: return "Talk to Me Heath"
        case .listening: return isLocked ? "Listening — tap to send" : "Listening…"
        case .thinking: return "Thinking…"
        case .speaking: return "Hermes"
        case .offline: return "Tap settings to connect"
        }
    }

    private var latestAssistant: ChatMessage? {
        conversation?.orderedMessages.last(where: { $0.role == .assistant })
    }

    private var canSendText: Bool {
        !keyboardDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shortModel: String {
        let id = config.selectedModel
        return id.count > 16 ? "…" + id.suffix(14) : id
    }

    // MARK: - Gesture (hold OR tap-lock)

    private var orbGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in if pressStartedAt == nil { handlePressDown() } }
            .onEnded { _ in handlePressUp() }
    }

    private func handlePressDown() {
        pressStartedAt = Date()
        if isLocked { return }          // a press while locked resolves on release (stop & send)
        startListening()
    }

    private func handlePressUp() {
        let held = Date().timeIntervalSince(pressStartedAt ?? Date())
        pressStartedAt = nil
        if isLocked {
            isLocked = false
            stopAndSend()
            return
        }
        if held < tapThreshold {
            isLocked = true             // quick tap → latch hands-free; keep recording
        } else {
            stopAndSend()               // hold-release → send
        }
    }

    /// VoiceOver / Switch Control entry point — the press-and-hold gesture isn't
    /// operable without sight, so expose a double-tap toggle: talk, then send.
    private func toggleTalkForAccessibility() {
        if recorder.isRecording {
            isLocked = false
            stopAndSend()
        } else {
            isLocked = true
            startListening()
        }
    }

    // MARK: - Voice + send

    private func startListening() {
        guard !recorder.isRecording else { return }
        liveTranscript = ""
        Task {
            let granted = await VoiceRecorder.requestAuthorization()
            guard granted else { permissionDenied = true; isLocked = false; return }
            try? await recorder.start()
        }
    }

    private func stopAndSend() {
        let final = recorder.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscript = ""
        guard !final.isEmpty else { return }
        sendText(final)
    }

    private func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ensureConversation()
        viewModel?.send(text: trimmed, images: [])
    }

    // MARK: - Session management

    private func ensureConversation() {
        if conversation == nil {
            let model = config.useAppleIntelligence ? config.selectedModel : config.selectedModel
            let convo = Conversation(model: model)
            modelContext.insert(convo)
            try? modelContext.save()
            conversation = convo
        }
        if viewModel == nil, let convo = conversation {
            viewModel = ChatViewModel(conversation: convo,
                                      client: HermesClient(config: config),
                                      config: config,
                                      context: modelContext)
        }
    }

    private func startNewSession() {
        showRecent = false
        conversation = nil
        viewModel = nil
        ensureConversation()
    }

    private func select(_ convo: Conversation) {
        showRecent = false
        conversation = convo
        viewModel = ChatViewModel(conversation: convo,
                                  client: HermesClient(config: config),
                                  config: config,
                                  context: modelContext)
    }

    private func loadModels() async {
        // Apple Intelligence is always ready — no server fetch needed.
        if config.useAppleIntelligence && config.appleIntelligenceClient != nil {
            reachable = true
            return
        }
        let client = HermesClient(config: config)
        if let fetched = try? await client.listModels(), !fetched.isEmpty {
            models = fetched
            reachable = true
            if config.selectedModel.isEmpty || !fetched.contains(where: { $0.id == config.selectedModel }) {
                config.selectedModel = fetched.first!.id
            }
        } else {
            reachable = false
        }
    }
}
