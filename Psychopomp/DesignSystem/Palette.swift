import SwiftUI

/// How the orb is rendered for a theme.
enum OrbStyle {
    case glow   // luminous sphere with bloom — for dark themes
    case jewel  // dark polished stone with a bright specular — for light themes
}

/// A complete set of design colors for one theme. Field names match the existing
/// `Theme.Color` tokens exactly, so consuming views never change.
struct Palette {
    let bg, canvas, canvasTop, surface, raised, border: Color
    let textPrimary, textSecondary, textDim: Color
    let textCool, textCoolDim, textCoolFaint: Color
    let accent, aura, aura2, green, red: Color
    let orbHighlight, orbMid, orbDeep, orbCore, orbOffline: Color
    let orbStyle: OrbStyle
    let colorScheme: ColorScheme
}

/// The selectable themes.
enum ThemeID: String, CaseIterable, Identifiable {
    case ethereal, traditionalDark, traditionalLight, catppuccinMocha, catppuccinLatte, catpoopchin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ethereal: return "Ethereal"
        case .traditionalDark: return "Dark"
        case .traditionalLight: return "Light"
        case .catppuccinMocha: return "Catppuccin Mocha"
        case .catppuccinLatte: return "Catppuccin Latte"
        case .catpoopchin: return "Catpoopchin"
        }
    }

    var palette: Palette {
        switch self {
        case .ethereal: return .ethereal
        case .traditionalDark: return .traditionalDark
        case .traditionalLight: return .traditionalLight
        case .catppuccinMocha: return .catppuccinMocha
        case .catppuccinLatte: return .catppuccinLatte
        case .catpoopchin: return .catpoopchin
        }
    }
}

extension Palette {
    /// Default — the signature ethereal indigo (unchanged from the original tokens).
    static let ethereal = Palette(
        bg: Color(hex: 0x0B0B0C), canvas: Color(hex: 0x070912), canvasTop: Color(hex: 0x0E1424),
        surface: Color(hex: 0x161618), raised: Color(hex: 0x1E1E21), border: Color(hex: 0x2A2A2E),
        textPrimary: Color(hex: 0xE9E6DF), textSecondary: Color(hex: 0x9A968C), textDim: Color(hex: 0x5E5B54),
        textCool: Color(hex: 0xDCE8FF), textCoolDim: Color(hex: 0x7E8BB5), textCoolFaint: Color(hex: 0x566190),
        accent: Color(hex: 0xCDB089), aura: Color(hex: 0x7C96FF), aura2: Color(hex: 0x9678FF),
        green: Color(hex: 0x7FB89B), red: Color(hex: 0xC8736B),
        orbHighlight: Color(hex: 0xEEF9FF), orbMid: Color(hex: 0xACD6FF), orbDeep: Color(hex: 0x6F7CFF),
        orbCore: Color(hex: 0x241A3A), orbOffline: Color(hex: 0x4A4E63),
        orbStyle: .glow, colorScheme: .dark)

    static let traditionalDark = Palette(
        bg: Color(hex: 0x000000), canvas: Color(hex: 0x0A0A0B), canvasTop: Color(hex: 0x141416),
        surface: Color(hex: 0x1C1C1E), raised: Color(hex: 0x2C2C2E), border: Color(hex: 0x38383A),
        textPrimary: Color(hex: 0xFFFFFF), textSecondary: Color(hex: 0xAEAEB2), textDim: Color(hex: 0x636366),
        textCool: Color(hex: 0xFFFFFF), textCoolDim: Color(hex: 0xAEAEB2), textCoolFaint: Color(hex: 0x636366),
        accent: Color(hex: 0x0A84FF), aura: Color(hex: 0x0A84FF), aura2: Color(hex: 0x5E9EFF),
        green: Color(hex: 0x30D158), red: Color(hex: 0xFF453A),
        orbHighlight: Color(hex: 0xDCE9FF), orbMid: Color(hex: 0x5EA2FF), orbDeep: Color(hex: 0x0A84FF),
        orbCore: Color(hex: 0x0A2A55), orbOffline: Color(hex: 0x48484A),
        orbStyle: .glow, colorScheme: .dark)

    static let traditionalLight = Palette(
        bg: Color(hex: 0xFFFFFF), canvas: Color(hex: 0xF2F2F7), canvasTop: Color(hex: 0xFFFFFF),
        surface: Color(hex: 0xFFFFFF), raised: Color(hex: 0xF2F2F7), border: Color(hex: 0xD1D1D6),
        textPrimary: Color(hex: 0x1C1C1E), textSecondary: Color(hex: 0x3A3A3C), textDim: Color(hex: 0x8E8E93),
        textCool: Color(hex: 0x1C1C1E), textCoolDim: Color(hex: 0x3A3A3C), textCoolFaint: Color(hex: 0x8E8E93),
        accent: Color(hex: 0x007AFF), aura: Color(hex: 0x007AFF), aura2: Color(hex: 0x5E9EFF),
        green: Color(hex: 0x34C759), red: Color(hex: 0xFF3B30),
        orbHighlight: Color(hex: 0xCFE0FF), orbMid: Color(hex: 0x3D5FA8), orbDeep: Color(hex: 0x20305C),
        orbCore: Color(hex: 0x0C1730), orbOffline: Color(hex: 0xC7C7CC),
        orbStyle: .jewel, colorScheme: .light)

    static let catppuccinMocha = Palette(
        bg: Color(hex: 0x1E1E2E), canvas: Color(hex: 0x181825), canvasTop: Color(hex: 0x1E1E2E),
        surface: Color(hex: 0x313244), raised: Color(hex: 0x45475A), border: Color(hex: 0x45475A),
        textPrimary: Color(hex: 0xCDD6F4), textSecondary: Color(hex: 0xA6ADC8), textDim: Color(hex: 0x6C7086),
        textCool: Color(hex: 0xCDD6F4), textCoolDim: Color(hex: 0xA6ADC8), textCoolFaint: Color(hex: 0x6C7086),
        accent: Color(hex: 0xCBA6F7), aura: Color(hex: 0x89B4FA), aura2: Color(hex: 0xB4BEFE),
        green: Color(hex: 0xA6E3A1), red: Color(hex: 0xF38BA8),
        orbHighlight: Color(hex: 0xF0E9FF), orbMid: Color(hex: 0xCBA6F7), orbDeep: Color(hex: 0x89B4FA),
        orbCore: Color(hex: 0x45456B), orbOffline: Color(hex: 0x6C7086),
        orbStyle: .glow, colorScheme: .dark)

    static let catppuccinLatte = Palette(
        bg: Color(hex: 0xEFF1F5), canvas: Color(hex: 0xE6E9EF), canvasTop: Color(hex: 0xEFF1F5),
        surface: Color(hex: 0xE6E9EF), raised: Color(hex: 0xDCE0E8), border: Color(hex: 0xCCD0DA),
        textPrimary: Color(hex: 0x4C4F69), textSecondary: Color(hex: 0x6C6F85), textDim: Color(hex: 0x9CA0B0),
        textCool: Color(hex: 0x4C4F69), textCoolDim: Color(hex: 0x6C6F85), textCoolFaint: Color(hex: 0x9CA0B0),
        accent: Color(hex: 0x8839EF), aura: Color(hex: 0x8839EF), aura2: Color(hex: 0x7287FD),
        green: Color(hex: 0x40A02B), red: Color(hex: 0xD20F39),
        orbHighlight: Color(hex: 0xD9C4F5), orbMid: Color(hex: 0x6B4BA0), orbDeep: Color(hex: 0x36285C),
        orbCore: Color(hex: 0x1E1B2E), orbOffline: Color(hex: 0x9CA0B0),
        orbStyle: .jewel, colorScheme: .light)

    static let catpoopchin = Palette(
        bg: Color(hex: 0x2B1D0E), canvas: Color(hex: 0x1A110A), canvasTop: Color(hex: 0x2B1D0E),
        surface: Color(hex: 0x3D2B1A), raised: Color(hex: 0x4E3A24), border: Color(hex: 0x5C4530),
        textPrimary: Color(hex: 0xD4C4A0), textSecondary: Color(hex: 0xA89070), textDim: Color(hex: 0x6B5A42),
        textCool: Color(hex: 0xC8B888), textCoolDim: Color(hex: 0x8A7A58), textCoolFaint: Color(hex: 0x5C4E38),
        accent: Color(hex: 0x9B8B30), aura: Color(hex: 0x7A6B20), aura2: Color(hex: 0x8B7B28),
        green: Color(hex: 0x6B7B30), red: Color(hex: 0x8B3A20),
        orbHighlight: Color(hex: 0xE8D8A0), orbMid: Color(hex: 0xB8A060), orbDeep: Color(hex: 0x7A6530),
        orbCore: Color(hex: 0x3A2A10), orbOffline: Color(hex: 0x5A4A30),
        orbStyle: .glow, colorScheme: .dark)
}
