import SwiftUI
import SwiftData

/// The swipe-up history sheet. Lists past conversations; lets the user continue one
/// by voice (`onSelect`), open its full transcript (`onOpen`), start a new session
/// (`onNew`), or delete.
struct RecentSessionsSheet: View {
    let current: Conversation?
    let onSelect: (Conversation) -> Void
    let onOpen: (Conversation) -> Void
    let onNew: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    var body: some View {
        NavigationStack {
            List {
                Button(action: onNew) {
                    Label("New session", systemImage: "plus")
                        .font(Theme.Font.sansBody)
                        .foregroundStyle(Theme.Color.aura)
                }
                .listRowBackground(Theme.Color.surface)

                ForEach(conversations) { convo in
                    row(convo)
                        .listRowBackground(Theme.Color.surface)
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.Color.canvas)
            .navigationTitle("Recent sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Theme.Color.aura)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.Color.canvas)
    }

    private func row(_ convo: Conversation) -> some View {
        HStack {
            Button { onSelect(convo) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if convo.id == current?.id {
                            Circle().fill(Theme.Color.green).frame(width: 6, height: 6)
                        }
                        Text(convo.title)
                            .font(Theme.Font.sansBody)
                            .foregroundStyle(Theme.Color.textCool)
                            .lineLimit(1)
                    }
                    Text(convo.updatedAt, format: .relative(presentation: .named))
                        .font(Theme.Font.sansCaption)
                        .foregroundStyle(Theme.Color.textCoolFaint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button { onOpen(convo) } label: {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Theme.Color.textCoolDim)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open full transcript")
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(conversations[index]) }
        try? modelContext.save()
    }
}
