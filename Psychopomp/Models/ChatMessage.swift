import Foundation
import SwiftData

enum ChatRole: String, Codable, Sendable {
    case system, user, assistant
}

enum MessageStatus: String, Codable, Sendable {
    case complete    // finished message
    case streaming   // assistant message currently being streamed
    case stopped     // run was stopped by the user
    case failed      // run errored
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    private var roleRaw: String
    private var statusRaw: String
    var text: String
    var createdAt: Date

    var conversation: Conversation?

    @Relationship(deleteRule: .cascade, inverse: \ToolEvent.message)
    var toolEvents: [ToolEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \Attachment.message)
    var attachments: [Attachment] = []

    init(id: UUID = UUID(),
         role: ChatRole,
         text: String = "",
         status: MessageStatus = .complete,
         createdAt: Date = .now) {
        self.id = id
        self.roleRaw = role.rawValue
        self.statusRaw = status.rawValue
        self.text = text
        self.createdAt = createdAt
    }

    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .assistant }
        set { roleRaw = newValue.rawValue }
    }

    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRaw) ?? .complete }
        set { statusRaw = newValue.rawValue }
    }

    var orderedToolEvents: [ToolEvent] {
        toolEvents.sorted { $0.timestamp < $1.timestamp }
    }
}
