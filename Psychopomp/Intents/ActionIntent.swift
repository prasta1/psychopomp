import AppIntents

/// Intent that starts a voice conversation when triggered via the Action Button,
/// Shortcuts, or Siri. Opens the app and immediately begins listening.
@available(iOS 16.0, *)
struct StartVoiceConversationIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Voice Conversation"
    static var description = IntentDescription(
        "Opens Psychopomp and starts listening for your message."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .actionButtonTriggered,
            object: nil,
            userInfo: ["mode": IntentAction.voiceConversation]
        )
        return .result()
    }
}

/// Intent that opens the app to the keyboard for a typed message.
@available(iOS 16.0, *)
struct StartTypedMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Type a Message"
    static var description = IntentDescription(
        "Opens Psychopomp with the keyboard ready for typing."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .actionButtonTriggered,
            object: nil,
            userInfo: ["mode": IntentAction.typedMessage]
        )
        return .result()
    }
}

// MARK: - Shared types

enum IntentAction: String {
    case voiceConversation
    case typedMessage
}

extension Notification.Name {
    static let actionButtonTriggered = Notification.Name("psychopomp.actionButtonTriggered")
}
