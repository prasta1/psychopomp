import Foundation
import SwiftData

enum ToolStatus: String, Codable, Sendable {
    case running, succeeded, failed
}

/// A single tool-call step surfaced by Hermes during a run (e.g. terminal, web
/// search, file ops). Rendered inline as a progress timeline under the assistant
/// message it belongs to.
@Model
final class ToolEvent {
    @Attribute(.unique) var id: UUID
    var name: String
    private var statusRaw: String
    /// Short human-readable detail, e.g. the command or query.
    var detail: String
    var timestamp: Date

    var message: ChatMessage?

    init(id: UUID = UUID(),
         name: String,
         status: ToolStatus = .running,
         detail: String = "",
         timestamp: Date = .now) {
        self.id = id
        self.name = name
        self.statusRaw = status.rawValue
        self.detail = detail
        self.timestamp = timestamp
    }

    var status: ToolStatus {
        get { ToolStatus(rawValue: statusRaw) ?? .running }
        set { statusRaw = newValue.rawValue }
    }
}
