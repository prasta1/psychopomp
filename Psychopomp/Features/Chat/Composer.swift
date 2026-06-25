import SwiftUI
import UIKit
import PhotosUI

/// The message input bar: text field, image attachment, voice recording, and a send button that
/// becomes a stop button while a run is streaming.
struct Composer: View {
    @Binding var text: String
    let isStreaming: Bool
    let canSend: Bool
    let onSend: ([Data]) -> Void
    let onStop: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [Data] = []
    @State private var recorder = VoiceRecorder()
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
                .disabled(isStreaming || recorder.isRecording)

                TextField(recorder.isRecording ? "Listening…" : "Message Hermes…", text: $text, axis: .vertical)
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
                            .strokeBorder(recorder.isRecording ? Theme.Color.green : Theme.Color.border, lineWidth: 1)
                    )

                micButton
                actionButton
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.bg)
        .overlay(alignment: .top) { Hairline() }
        .onChange(of: pickerItems) { _, items in
            Task { await load(items) }
        }
        // Stream live transcript into the text field while recording.
        .onChange(of: recorder.transcript) { _, new in
            if recorder.isRecording { text = new }
        }
    }

    // MARK: - Mic Button

    @ViewBuilder
    private var micButton: some View {
        Button {
            if recorder.isRecording {
                sendVoice()
            } else {
                Task {
                    let granted = await VoiceRecorder.requestAuthorization()
                    guard granted else { return }
                    try? recorder.start()
                }
            }
        } label: {
            Image(systemName: recorder.isRecording ? "waveform" : "mic")
                .font(.system(size: 18))
                .foregroundStyle(recorder.isRecording ? Theme.Color.green : Theme.Color.textSecondary)
                .frame(width: 40, height: 40)
                .background(recorder.isRecording ? Theme.Color.green.opacity(0.15) : Color.clear)
                .clipShape(Circle())
                .symbolEffect(.variableColor.reversing, options: .repeating, isActive: recorder.isRecording)
        }
        .buttonStyle(.plain)
        .disabled(isStreaming)
    }

    // MARK: - Send / Stop Button

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
                // If recording, stop it first so the final transcript is captured.
                if recorder.isRecording { _ = recorder.stop() }
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
        canSend && (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty || recorder.isRecording)
    }

    // MARK: - Helpers

    /// Stops voice recording and immediately sends the transcribed text.
    private func sendVoice() {
        let final = recorder.stop()
        let trimmed = final.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty else { return }
        text = trimmed
        let payload = images
        onSend(payload)
        images.removeAll()
        pickerItems.removeAll()
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
