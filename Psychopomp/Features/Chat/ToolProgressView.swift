import SwiftUI

/// Inline timeline of the tool calls Hermes made while producing a message.
struct ToolProgressView: View {
    let events: [ToolEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(events) { event in
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    icon(for: event.status)
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.name)
                            .font(Theme.Font.caption.weight(.semibold))
                            .foregroundStyle(Theme.Color.textSecondary)
                        if !event.detail.isEmpty {
                            Text(event.detail)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textDim)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Color.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .strokeBorder(Theme.Color.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func icon(for status: ToolStatus) -> some View {
        switch status {
        case .running:
            ProgressView().controlSize(.mini).tint(Theme.Color.accent)
        case .succeeded:
            Image(systemName: "checkmark").font(.caption2).foregroundStyle(Theme.Color.green)
        case .failed:
            Image(systemName: "xmark").font(.caption2).foregroundStyle(Theme.Color.red)
        }
    }
}
