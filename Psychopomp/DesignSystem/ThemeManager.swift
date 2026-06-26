import SwiftUI

/// Holds the selected theme and exposes its palette. A singleton so the static
/// `Theme.Color.*` accessors can resolve colors without view-context plumbing;
/// `@Observable` so every view that reads those colors re-renders on switch.
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    /// The active theme. Persisted to UserDefaults on change.
    var selected: ThemeID {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: Self.key) }
    }

    /// Colors for the active theme.
    var palette: Palette { selected.palette }

    private static let key = "theme.selected"

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.key)
        selected = raw.flatMap(ThemeID.init(rawValue:)) ?? .ethereal
    }
}
