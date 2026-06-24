import SwiftUI

/// Presented when the agent requests approval before running a sensitive tool.
struct ApprovalSheet: View {
    let request: ApprovalRequest
    let onResolve: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Theme.Color.accent)
                Text("Approval required")
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.Color.textPrimary)
            }

            SectionLabel("Tool")
            Text(request.toolName)
                .font(Theme.Font.body.weight(.semibold))
                .foregroundStyle(Theme.Color.textPrimary)

            if !request.detail.isEmpty {
                SectionLabel("Details")
                ScrollView {
                    Text(request.detail)
                        .font(Theme.Font.code)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 180)
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            }

            Spacer()

            HStack(spacing: Theme.Spacing.md) {
                TerminalButton(title: "Deny", kind: .secondary) { onResolve(false) }
                TerminalButton(title: "Approve", systemImage: "checkmark", kind: .primary) { onResolve(true) }
            }
        }
        .padding(Theme.Spacing.xl)
        .screenBackground()
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.Color.bg)
    }
}
