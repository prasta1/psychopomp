import Foundation
import SwiftData
import SwiftUI

/// Drives a single conversation: builds the request from history, streams the
/// run, and writes deltas / tool events / approvals back into SwiftData.
@MainActor
@Observable
final class ChatViewModel {
    let conversation: Conversation
    private let client: HermesClient
    private let config: HermesConfig
    private let context: ModelContext

    var isStreaming = false
    var errorMessage: String?
    var pendingApproval: ApprovalRequest?

    private var currentRunId = ""
    private var streamTask: Task<Void, Never>?
    private var streamingMessage: ChatMessage?
    /// Maps a server-side tool/call id to the persisted ToolEvent for that step.
    private var toolIndex: [String: ToolEvent] = [:]

    init(conversation: Conversation, client: HermesClient, config: HermesConfig, context: ModelContext) {
        self.conversation = conversation
        self.client = client
        self.config = config
        self.context = context
    }

    var canSend: Bool {
        guard !isStreaming else { return false }
        if config.useAppleIntelligence && config.appleIntelligenceClient != nil { return true }
        return config.isConfigured && !config.selectedModel.isEmpty
    }

    // MARK: Sending

    func send(text: String, images: [Data]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isStreaming, !(trimmed.isEmpty && images.isEmpty) else { return }
        errorMessage = nil

        let user = ChatMessage(role: .user, text: trimmed, status: .complete)
        user.conversation = conversation
        context.insert(user)
        for data in images {
            let attachment = Attachment(data: data)
            attachment.message = user
            context.insert(attachment)
        }
        conversation.updatedAt = .now
        conversation.deriveTitleIfNeeded()
        save()

        let history = buildWireHistory()

        let assistant = ChatMessage(role: .assistant, status: .streaming)
        assistant.conversation = conversation
        context.insert(assistant)
        save()

        streamingMessage = assistant
        toolIndex.removeAll()
        startStream(history: history, latestText: trimmed, assistant: assistant)
    }

    private func startStream(history: [WireMessage], latestText: String, assistant: ChatMessage) {
        isStreaming = true
        currentRunId = ""
        conversation.model = config.selectedModel

        // Route to Apple Intelligence when it is the active provider.
        if config.useAppleIntelligence,
           #available(iOS 26.0, *),
           let aiClient = config.appleIntelligenceClient as? AppleIntelligenceClient {
            let convId = conversation.id
            streamTask = Task { @MainActor in
                do {
                    for try await event in aiClient.stream(conversationId: convId, prompt: latestText) {
                        handle(event, assistant: assistant)
                    }
                } catch is CancellationError {
                    // user stopped
                } catch {
                    assistant.status = .failed
                    errorMessage = error.localizedDescription
                    if assistant.text.isEmpty { assistant.text = "⚠︎ \(error.localizedDescription)" }
                }
                finalize(assistant)
            }
            return
        }

        // Hermes path.
        let model = config.selectedModel
        let sessionKey = conversation.id.uuidString
        streamTask = Task { @MainActor in
            do {
                for try await event in client.stream(messages: history, model: model, sessionKey: sessionKey) {
                    handle(event, assistant: assistant)
                }
            } catch is CancellationError {
                // user stopped; handled in stop()
            } catch {
                assistant.status = .failed
                errorMessage = error.localizedDescription
                if assistant.text.isEmpty {
                    assistant.text = "⚠︎ \(error.localizedDescription)"
                }
            }
            finalize(assistant)
        }
    }

    private func handle(_ event: StreamEvent, assistant: ChatMessage) {
        switch event {
        case .runId(let id):
            currentRunId = id
        case .textDelta(let delta):
            assistant.text += delta
        case .toolStarted(let id, let name, let detail):
            upsertTool(serverId: id, name: name, detail: detail, on: assistant)
        case .toolFinished(let id, let success):
            finishTool(serverId: id, success: success, on: assistant)
        case .approvalRequired(let request):
            var request = request
            if request.runId.isEmpty {
                request = ApprovalRequest(id: request.id, runId: currentRunId,
                                          toolName: request.toolName, detail: request.detail)
            }
            pendingApproval = request
        case .completed, .done:
            if assistant.status == .streaming { assistant.status = .complete }
        case .failed(let message):
            assistant.status = .failed
            errorMessage = message
            if assistant.text.isEmpty { assistant.text = "⚠︎ \(message)" }
        }
        conversation.updatedAt = .now
        save()
    }

    private func finalize(_ assistant: ChatMessage) {
        if assistant.status == .streaming { assistant.status = .complete }
        isStreaming = false
        streamingMessage = nil
        save()
    }

    // MARK: Control

    func stop() {
        guard isStreaming else { return }
        streamTask?.cancel()
        let runId = currentRunId
        Task { await client.stop(runId: runId) }
        if let assistant = streamingMessage {
            assistant.status = .stopped
        }
        isStreaming = false
        save()
    }

    func resolveApproval(_ approved: Bool) {
        guard let request = pendingApproval else { return }
        pendingApproval = nil
        Task { await client.resolveApproval(runId: request.runId, approvalId: request.id, approved: approved) }
    }

    // MARK: Helpers

    private func buildWireHistory() -> [WireMessage] {
        conversation.orderedMessages
            .filter { $0.status != .streaming }
            .map(wire(from:))
    }

    private func wire(from message: ChatMessage) -> WireMessage {
        if message.role == .user, !message.attachments.isEmpty {
            var parts: [WirePart] = []
            if !message.text.isEmpty {
                parts.append(WirePart(type: "text", text: message.text))
            }
            for attachment in message.attachments {
                parts.append(WirePart(type: "image_url", image_url: .init(url: attachment.dataURI)))
            }
            return WireMessage(role: message.role.rawValue, content: .parts(parts))
        }
        return WireMessage(role: message.role.rawValue, content: .text(message.text))
    }

    private func upsertTool(serverId: String, name: String, detail: String, on assistant: ChatMessage) {
        if let existing = toolIndex[serverId] {
            if !detail.isEmpty { existing.detail = detail }
            return
        }
        let event = ToolEvent(name: name, status: .running, detail: detail)
        event.message = assistant
        context.insert(event)
        toolIndex[serverId] = event
    }

    private func finishTool(serverId: String, success: Bool, on assistant: ChatMessage) {
        if let existing = toolIndex[serverId] {
            existing.status = success ? .succeeded : .failed
        } else {
            let event = ToolEvent(name: "tool", status: success ? .succeeded : .failed)
            event.message = assistant
            context.insert(event)
            toolIndex[serverId] = event
        }
    }

    private func save() {
        do { try context.save() } catch { /* non-fatal; surfaced on next interaction */ }
    }
}
