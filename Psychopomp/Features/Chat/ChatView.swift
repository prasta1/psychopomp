import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: Conversation

    @Environment(\.modelContext) private var modelContext
    @Environment(HermesConfig.self) private var config

    @State private var viewModel: ChatViewModel?
    @State private var draft = ""
    @State private var models: [HermesModelInfo] = []

    var body: some View {
        VStack(spacing: 0) {
            transcript
            if let viewModel {
                Composer(
                    text: $draft,
                    isStreaming: viewModel.isStreaming,
                    canSend: viewModel.canSend,
                    onSend: { images in
                        viewModel.send(text: draft, images: images)
                        draft = ""
                    },
                    onStop: { viewModel.stop() }
                )
            }
        }
        .screenBackground()
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task(id: conversation.id) {
            viewModel = ChatViewModel(conversation: conversation,
                                      client: HermesClient(config: config),
                                      config: config,
                                      context: modelContext)
            await loadModels()
            // Consume a voice transcript captured via the PTT button on the list screen.
            let pending = config.pendingVoiceTranscript
            if !pending.isEmpty {
                config.pendingVoiceTranscript = ""
                viewModel?.send(text: pending, images: [])
            }
        }
        .sheet(item: approvalBinding) { request in
            ApprovalSheet(request: request) { approved in
                viewModel?.resolveApproval(approved)
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(conversation.orderedMessages) { message in
                        MessageRow(message: message,
                                   isStreaming: message.status == .streaming && (viewModel?.isStreaming ?? false))
                            .id(message.id)
                        Hairline().opacity(0.4)
                    }
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: conversation.orderedMessages.last?.text) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
            .onChange(of: conversation.messages.count) { _, _ in
                withAnimation { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
            .overlay { if conversation.messages.isEmpty { emptyState } }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("_")
                .font(.system(size: 48, design: .monospaced))
                .foregroundStyle(Theme.Color.green)
            Text("Hermes is listening.")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
            if config.selectedModel.isEmpty {
                Text("Pick a model from the menu to begin.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textDim)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if models.isEmpty {
                    Text("No models loaded")
                } else {
                    Picker("Model", selection: modelSelection) {
                        ForEach(models) { model in
                            Text(model.id).tag(model.id)
                        }
                    }
                }
                Button {
                    Task { await loadModels() }
                } label: { Label("Reload models", systemImage: "arrow.clockwise") }
            } label: {
                HStack(spacing: 4) {
                    Text(config.selectedModel.isEmpty ? "model" : shortModel)
                        .font(Theme.Font.caption)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .foregroundStyle(Theme.Color.accent)
            }
        }
    }

    private var shortModel: String {
        let id = config.selectedModel
        return id.count > 18 ? "…" + id.suffix(16) : id
    }

    private var modelSelection: Binding<String> {
        Binding(get: { config.selectedModel }, set: { config.selectedModel = $0 })
    }

    private var approvalBinding: Binding<ApprovalRequest?> {
        Binding(get: { viewModel?.pendingApproval }, set: { if $0 == nil { viewModel?.pendingApproval = nil } })
    }

    private var bottomAnchor: String { "bottom-anchor" }

    private func loadModels() async {
        let client = HermesClient(config: config)
        if let fetched = try? await client.listModels(), !fetched.isEmpty {
            models = fetched
            if config.selectedModel.isEmpty || !fetched.contains(where: { $0.id == config.selectedModel }) {
                config.selectedModel = fetched.first!.id
            }
        }
    }
}
