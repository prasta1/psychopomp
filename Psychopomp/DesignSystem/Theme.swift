import SwiftUI

/// Central design tokens for Psychopomp.
///
/// The palette approximates Nous Research's retro-terminal aesthetic: a near-black
/// canvas, warm off-white monospace text, and a restrained amber accent. Everything
/// lives here so the look can be tuned in one place to match Nous's exact brand.
enum Theme {

    // MARK: Color

    enum Color {
        /// App canvas — near black, very slightly warm.
        static let bg = SwiftUI.Color(hex: 0x0B0B0C)
        /// Cards, composer, raised rows.
        static let surface = SwiftUI.Color(hex: 0x161618)
        /// Raised-on-surface (sheets, code blocks).
        static let raised = SwiftUI.Color(hex: 0x1E1E21)
        /// Hairline separators / outlines.
        static let border = SwiftUI.Color(hex: 0x2A2A2E)

        /// Primary copy — warm off-white.
        static let textPrimary = SwiftUI.Color(hex: 0xE9E6DF)
        /// Secondary copy / metadata.
        static let textSecondary = SwiftUI.Color(hex: 0x9A968C)
        /// Dim copy / placeholders.
        static let textDim = SwiftUI.Color(hex: 0x5E5B54)

        /// Primary accent — phosphor amber. Cursor, links, send action.
        static let accent = SwiftUI.Color(hex: 0xCDB089)
        /// Tool / success.
        static let green = SwiftUI.Color(hex: 0x7FB89B)
        /// Errors / destructive / stop.
        static let red = SwiftUI.Color(hex: 0xC8736B)

        // MARK: Ethereal (orb home)

        /// Deep indigo-black canvas for the orb screen (top of the radial wash).
        static let canvasTop = SwiftUI.Color(hex: 0x0E1424)
        /// Deep indigo-black canvas (outer).
        static let canvas = SwiftUI.Color(hex: 0x070912)

        /// Orb gradient stops: white-blue core → sky → periwinkle → deep core.
        static let orbHighlight = SwiftUI.Color(hex: 0xEEF9FF)
        static let orbMid = SwiftUI.Color(hex: 0xACD6FF)
        static let orbDeep = SwiftUI.Color(hex: 0x6F7CFF)
        static let orbCore = SwiftUI.Color(hex: 0x241A3A)

        /// Aura / glow + swirl accents.
        static let aura = SwiftUI.Color(hex: 0x7C96FF)
        static let aura2 = SwiftUI.Color(hex: 0x9678FF)

        /// Cool text scale for the orb screen.
        static let textCool = SwiftUI.Color(hex: 0xDCE8FF)
        static let textCoolDim = SwiftUI.Color(hex: 0x7E8BB5)
        static let textCoolFaint = SwiftUI.Color(hex: 0x566190)

        /// Desaturated orb for the offline / error state.
        static let orbOffline = SwiftUI.Color(hex: 0x4A4E63)
    }

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
