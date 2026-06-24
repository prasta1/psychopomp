import SwiftUI
import UIKit

/// One message in the transcript, rendered terminal-style with a leading role
/// marker rather than a chat bubble.
struct MessageRow: View {
    let message: ChatMessage
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            RoleMarker(symbol: marker, color: markerColor)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if !message.attachments.isEmpty {
                    attachments
                }

                if message.role == .user {
                    Text(message.text)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .textSelection(.enabled)
                } else {
                    if !message.orderedToolEvents.isEmpty {
                        ToolProgressView(events: message.orderedToolEvents)
                    }
                    if !message.text.isEmpty {
                        MarkdownText(text: message.text)
                    }
                    if isStreaming {
                        BlinkingCursor()
                    }
                }

                if message.status == .stopped {
                    StatusPill(text: "stopped", color: Theme.Color.textDim)
                } else if message.status == .failed {
                    StatusPill(text: "failed", color: Theme.Color.red)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var attachments: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(message.attachments) { attachment in
                    if let image = UIImage(data: attachment.data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    }
                }
            }
        }
    }

    private var marker: String {
        switch message.role {
        case .user: return "›"
        case .assistant: return "_"
        case .system: return "#"
        }
    }

    private var markerColor: Color {
        message.role == .user ? Theme.Color.accent : Theme.Color.green
    }
}
