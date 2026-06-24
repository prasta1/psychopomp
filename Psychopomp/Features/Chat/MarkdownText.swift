import SwiftUI
import UIKit

/// Lightweight markdown renderer: splits text into prose and fenced ``` code
/// blocks, rendering prose with `AttributedString(markdown:)` (inline emphasis,
/// links, inline code) and code blocks in a bordered monospace panel.
///
/// Zero dependencies. For richer rendering (tables, nested lists, syntax
/// highlighting) swap in swift-markdown-ui later behind this same view.
struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .prose(let value):
                    Text(inlineAttributed(value))
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .textSelection(.enabled)
                case .code(let language, let code):
                    CodeBlock(language: language, code: code)
                }
            }
        }
    }

    private enum Segment {
        case prose(String)
        case code(language: String, code: String)
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var prose: [String] = []
        var code: [String] = []
        var inFence = false
        var fenceLang = ""

        func flushProse() {
            let joined = prose.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { result.append(.prose(joined)) }
            prose.removeAll()
        }

        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inFence {
                    result.append(.code(language: fenceLang, code: code.joined(separator: "\n")))
                    code.removeAll()
                    inFence = false
                    fenceLang = ""
                } else {
                    flushProse()
                    inFence = true
                    fenceLang = line.trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
            } else if inFence {
                code.append(line)
            } else {
                prose.append(line)
            }
        }
        if inFence { result.append(.code(language: fenceLang, code: code.joined(separator: "\n"))) }
        flushProse()
        return result
    }

    /// Render inline markdown, falling back to plain text if parsing fails.
    private func inlineAttributed(_ value: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: value, options: options) {
            return attributed
        }
        return AttributedString(value)
    }
}

private struct CodeBlock: View {
    let language: String
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "code" : language)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textDim)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Color.raised)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(Theme.Font.code)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .textSelection(.enabled)
                    .padding(Theme.Spacing.md)
            }
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.Color.border, lineWidth: 1)
        )
    }
}
