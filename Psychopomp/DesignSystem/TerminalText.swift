import SwiftUI

/// A blinking block cursor, shown at the tail of streaming assistant output.
struct BlinkingCursor: View {
    @State private var on = true

    var body: some View {
        Text("\u{2588}") // █ full block
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Color.accent)
            .opacity(on ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    on = false
                }
            }
            .accessibilityHidden(true)
    }
}

/// A leading role marker (e.g. `›` for the user, `_` for the assistant) rendered
/// in the terminal style instead of chat bubbles.
struct RoleMarker: View {
    let symbol: String
    let color: Color

    var body: some View {
        Text(symbol)
            .font(Theme.Font.body.weight(.bold))
            .foregroundStyle(color)
            .frame(width: 16, alignment: .leading)
            .accessibilityHidden(true)
    }
}

/// Section label rendered like a terminal prompt, e.g. `// CONNECTION`.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text("// \(text.uppercased())")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textDim)
            .tracking(1.5)
    }
}
