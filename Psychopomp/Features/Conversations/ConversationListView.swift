import SwiftUI
import SwiftData

/// Home screen: the list of saved sessions with entry points to create a new
/// one or open settings.
struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HermesConfig.self) private var config

    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    @State private var path: [Conversation] = []
    @State private var showSettings = false
    @State private var recorder = VoiceRecorder()
    @State private var liveTranscript = ""

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if conversations.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .screenBackground()
            .navigationTitle("Hermes")
            .toolbar { toolbarContent }
            .navigationDestination(for: Conversation.self) { ChatView(conversation: $0) }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .safeAreaInset(edge: .bottom) { pttBar }
            .onChange(of: recorder.transcript) { _, new in
                if recorder.isRecording { liveTranscript = new }
            }
        }
        .tint(Theme.Color.accent)
    }

    // MARK: - PTT Bar

    private var pttBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if recorder.isRecording && !liveTranscript.isEmpty {
                Text(liveTranscript)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .transition(.opacity)
            }

            ZStack {
                Capsule()
                    .fill(recorder.isRecording ? Theme.Color.green.opacity(0.15) : Theme.Color.surface)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                recorder.isRecording ? Theme.Color.green : Theme.Color.border,
                                lineWidth: 1
                            )
                    )

                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                        .symbolEffect(.variableColor.reversing, options: .repeating, isActive: recorder.isRecording)
                    Text(recorder.isRecording ? "Listening…" : "Talk to Me Heath")
                }
                .font(Theme.Font.callout)
                .foregroundStyle(recorder.isRecording ? Theme.Color.green : Theme.Color.accent)
            }
            .frame(height: 52)
            .padding(.horizontal, Theme.Spacing.xl)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in startPTT() }
                    .onEnded { _ in stopPTT() }
            )
        }
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Color.bg)
        .overlay(alignment: .top) { Hairline() }
        .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
    }

    private func startPTT() {
        guard !recorder.isRecording else { return }
        liveTranscript = ""
        Task {
            let granted = await VoiceRecorder.requestAuthorization()
            guard granted else { return }
            try? await recorder.start()
        }
    }

    private func stopPTT() {
        let transcript = recorder.stop()
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscript = ""
        guard !trimmed.isEmpty else { return }
        config.pendingVoiceTranscript = trimmed
        newConversation()
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(conversations) { conversation in
                Button { path.append(conversation) } label: { row(conversation) }
                    .listRowBackground(Theme.Color.bg)
                    .listRowSeparatorTint(Theme.Color.border)
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ conversation: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conversation.title)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
                .lineLimit(1)
            HStack(spacing: Theme.Spacing.sm) {
                Text(conversation.updatedAt, format: .relative(presentation: .named))
                if !conversation.model.isEmpty {
                    Text("· \(conversation.model)").lineLimit(1)
                }
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textDim)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("psychopomp")
                .font(Theme.Font.display)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("Your companion to the Hermes agent.")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
            TerminalButton(title: "New session", systemImage: "plus") { newConversation() }
                .frame(maxWidth: 240)
                .padding(.top, Theme.Spacing.sm)
        }
        .padding(Theme.Spacing.xl)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").foregroundStyle(Theme.Color.textSecondary)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { newConversation() } label: {
                Image(systemName: "square.and.pencil").foregroundStyle(Theme.Color.accent)
            }
        }
    }

    private func newConversation() {
        let conversation = Conversation(model: config.selectedModel)
        modelContext.insert(conversation)
        try? modelContext.save()
        path.append(conversation)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(conversations[index]) }
        try? modelContext.save()
    }
}
