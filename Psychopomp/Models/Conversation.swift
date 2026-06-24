import Foundation
import SwiftData

/// A persisted chat thread. Its `id` doubles as the Hermes session key so
/// long-term agent memory stays stable per conversation.
@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    /// Model id used for this thread (e.g. the value returned by GET /v1/models).
    var model: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage] = []

    init(id: UUID = UUID(),
         title: String = "New session",
         model: String = "",
         createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.model = model
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// Messages in chronological order.
    var orderedMessages: [ChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    /// Derive a short title from the first user message.
    func deriveTitleIfNeeded() {
        guard title == "New session",
              let first = orderedMessages.first(where: { $0.role == .user })?.text,
              !first.isEmpty else { return }
        title = String(first.prefix(48))
    }
}
