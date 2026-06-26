import SwiftUI

/// Central design tokens for Psychopomp.
///
/// The palette approximates Nous Research's retro-terminal aesthetic: a near-black
/// canvas, warm off-white monospace text, and a restrained amber accent. Everything
/// lives here so the look can be tuned in one place to match Nous's exact brand.
enum Theme {

    // MARK: Color

    /// Active-theme colors. Names are unchanged so all consuming views keep working;
    /// values now resolve from `ThemeManager.shared.palette`, so switching themes
    /// re-renders the UI via Observation.
    enum Color {
        static var bg: SwiftUI.Color { ThemeManager.shared.palette.bg }
        static var canvas: SwiftUI.Color { ThemeManager.shared.palette.canvas }
        static var canvasTop: SwiftUI.Color { ThemeManager.shared.palette.canvasTop }
        static var surface: SwiftUI.Color { ThemeManager.shared.palette.surface }
        static var raised: SwiftUI.Color { ThemeManager.shared.palette.raised }
        static var border: SwiftUI.Color { ThemeManager.shared.palette.border }

        static var textPrimary: SwiftUI.Color { ThemeManager.shared.palette.textPrimary }
        static var textSecondary: SwiftUI.Color { ThemeManager.shared.palette.textSecondary }
        static var textDim: SwiftUI.Color { ThemeManager.shared.palette.textDim }

        static var textCool: SwiftUI.Color { ThemeManager.shared.palette.textCool }
        static var textCoolDim: SwiftUI.Color { ThemeManager.shared.palette.textCoolDim }
        static var textCoolFaint: SwiftUI.Color { ThemeManager.shared.palette.textCoolFaint }

        static var accent: SwiftUI.Color { ThemeManager.shared.palette.accent }
        static var aura: SwiftUI.Color { ThemeManager.shared.palette.aura }
        static var aura2: SwiftUI.Color { ThemeManager.shared.palette.aura2 }
        static var green: SwiftUI.Color { ThemeManager.shared.palette.green }
        static var red: SwiftUI.Color { ThemeManager.shared.palette.red }

        static var orbHighlight: SwiftUI.Color { ThemeManager.shared.palette.orbHighlight }
        static var orbMid: SwiftUI.Color { ThemeManager.shared.palette.orbMid }
        static var orbDeep: SwiftUI.Color { ThemeManager.shared.palette.orbDeep }
        static var orbCore: SwiftUI.Color { ThemeManager.shared.palette.orbCore }
        static var orbOffline: SwiftUI.Color { ThemeManager.shared.palette.orbOffline }
    }

    /// The orb render style for the active theme.
    static var orbStyle: OrbStyle { ThemeManager.shared.palette.orbStyle }

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Radius

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }

    // MARK: Typography — system monospaced throughout for the terminal feel.

    enum Font {
        static let display = SwiftUI.Font.system(.title2, design: .monospaced).weight(.bold)
        static let title = SwiftUI.Font.system(.headline, design: .monospaced).weight(.semibold)
        static let body = SwiftUI.Font.system(.body, design: .monospaced)
        static let callout = SwiftUI.Font.system(.callout, design: .monospaced)
        static let caption = SwiftUI.Font.system(.caption, design: .monospaced)
        static let code = SwiftUI.Font.system(.callout, design: .monospaced)

        // Soft sans for the orb home (a calmer counterpoint to the mono UI).
        static let sansTitle = SwiftUI.Font.system(.title3, design: .default).weight(.medium)
        static let sansBody = SwiftUI.Font.system(.body, design: .default)
        static let sansCaption = SwiftUI.Font.system(.caption, design: .default)
    }
}

extension Color {
    /// Build a color from a 0xRRGGBB literal. Takes `Int` (the default integer
    /// literal type) so large palette initializers type-check fast.
    init(hex: Int, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
