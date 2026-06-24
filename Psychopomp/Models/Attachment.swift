import Foundation
import SwiftData

/// An image attached to a user message. Stored as raw bytes on-device and sent to
/// Hermes inline as a `data:<mime>;base64,...` image_url part.
@Model
final class Attachment {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var data: Data
    var mimeType: String

    var message: ChatMessage?

    init(id: UUID = UUID(), data: Data, mimeType: String = "image/jpeg") {
        self.id = id
        self.data = data
        self.mimeType = mimeType
    }

    /// Inline data URI for the OpenAI-style `image_url` content part.
    var dataURI: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}
