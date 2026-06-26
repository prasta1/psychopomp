import SwiftUI
import SwiftData

@main
struct PsychopompApp: App {
    @State private var config = HermesConfig()

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
            RootView()
                .environment(config)
                .preferredColorScheme(.dark)
                .tint(Theme.Color.accent)
        }
        .modelContainer(modelContainer)
    }
}

/// Routes between onboarding and the conversation list depending on whether a
/// connection has been configured.
struct RootView: View {
    @Environment(HermesConfig.self) private var config
    @State private var connected = false

    var body: some View {
        Group {
            if config.isConfigured || connected {
                OrbHomeView()
            } else {
                ConnectionView { connected = true }
            }
        }
    }
}
