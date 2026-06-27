import SwiftUI
import SwiftData

@main
struct PsychopompApp: App {
    @State private var config = HermesConfig()
    @State private var theme = ThemeManager.shared
    @State private var pendingAction: IntentAction?

    /// Shared SwiftData stack for conversations, messages, tool events, attachments.
    let modelContainer: ModelContainer = {
        let schema = Schema([Conversation.self, ChatMessage.self, ToolEvent.self, Attachment.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView(pendingAction: $pendingAction)
                .environment(config)
                .environment(theme)
                .preferredColorScheme(theme.palette.colorScheme)
                .tint(Theme.Color.accent)
                .onReceive(NotificationCenter.default.publisher(for: .actionButtonTriggered)) { notification in
                    if let action = notification.userInfo?["mode"] as? IntentAction {
                        pendingAction = action
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}

/// Routes between onboarding and the conversation list depending on whether a
/// connection has been configured.
struct RootView: View {
    @Environment(HermesConfig.self) private var config
    @Binding var pendingAction: IntentAction?
    @State private var connected = false

    var body: some View {
        Group {
            if config.isConfigured || connected {
                OrbHomeView(pendingAction: $pendingAction)
            } else {
                ConnectionView { connected = true }
            }
        }
    }
}
