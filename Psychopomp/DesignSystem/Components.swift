import SwiftUI
import UIKit

/// A flat, terminal-styled button.
struct TerminalButton: View {
    enum Kind { case primary, secondary, destructive }

    let title: String
    var systemImage: String? = nil
    var kind: Kind = .primary
    var isLoading: Bool = false
    let action: () -> Void

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.Color.bg
        case .secondary: return Theme.Color.textPrimary
        case .destructive: return Theme.Color.bg
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return Theme.Color.accent
        case .secondary: return Theme.Color.surface
        case .destructive: return Theme.Color.red
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foreground)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(Theme.Font.callout.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(kind == .secondary ? Theme.Color.border : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

/// A full-width hairline separator.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Color.border)
            .frame(height: 1)
    }
}

/// A small status pill (used for tool events, connection state, etc.).
struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(Theme.Font.caption)
            .foregroundStyle(color)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

/// A bordered text field styled for the terminal theme.
struct TerminalField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var autocaps: TextInputAutocapitalization = .never

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .textInputAutocapitalization(autocaps)
        .autocorrectionDisabled()
        .keyboardType(keyboard)
        .font(Theme.Font.body)
        .foregroundStyle(Theme.Color.textPrimary)
        .tint(Theme.Color.accent)
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.Color.border, lineWidth: 1)
        )
    }
}

/// Convenience: apply the app background to a screen.
extension View {
    func screenBackground() -> some View {
        self.background(Theme.Color.bg.ignoresSafeArea())
    }

    /// The deep-indigo radial wash used by the orb home.
    func orbBackground() -> some View {
        self.background(
            RadialGradient(
                colors: [Theme.Color.canvasTop, Theme.Color.canvas],
                center: UnitPoint(x: 0.5, y: 0.28),
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()
        )
    }
}
