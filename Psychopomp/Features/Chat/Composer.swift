import SwiftUI
import UIKit
import PhotosUI

/// The message input bar: text field, image attachment, and a send button that
/// becomes a stop button while a run is streaming.
struct Composer: View {
    @Binding var text: String
    let isStreaming: Bool
    let canSend: Bool
    let onSend: ([Data]) -> Void
    let onStop: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [Data] = []
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                            thumbnail(data, index: index)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xs)
                }
            }

            HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 4, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(width: 40, height: 40)
                }
                .disabled(isStreaming)

                TextField("Message Hermes…", text: $text, axis: .vertical)
                    .focused($focused)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .tint(Theme.Color.accent)
                    .lineLimit(1...6)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .strokeBorder(Theme.Color.border, lineWidth: 1)
                    )

                actionButton
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.bg)
        .overlay(alignment: .top) { Hairline() }
        .onChange(of: pickerItems) { _, items in
            Task { await load(items) }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isStreaming {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Color.bg)
                    .frame(width: 40, height: 40)
                    .background(Theme.Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        } else {
            Button {
                let payload = images
                onSend(payload)
                images.removeAll()
                pickerItems.removeAll()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Color.bg)
                    .frame(width: 40, height: 40)
                    .background(isActive ? Theme.Color.accent : Theme.Color.border)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isActive)
        }
    }

    private var isActive: Bool {
        canSend && (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty)
    }

    private func thumbnail(_ data: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            }
            Button {
                images.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black)
                    .font(.system(size: 16))
            }
            .offset(x: 4, y: -4)
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        var loaded: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.7) {
                loaded.append(compressed)
            }
        }
        images = loaded
    }
}
