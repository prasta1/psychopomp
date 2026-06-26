# Multi-Theme System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add five runtime-switchable themes (Ethereal default, Traditional Dark/Light, Catppuccin Mocha/Latte) with a Settings picker; the orb glows on dark themes and renders as a dark jewel on light themes.

**Architecture:** A `Palette` value type (one per theme) is held by an `@Observable` `ThemeManager` singleton. The existing `Theme.Color.<name>` tokens become computed properties that read `ThemeManager.shared.palette.<name>`, so SwiftUI Observation re-renders the whole UI on switch with **zero changes to the ~15 consuming views**. The app root drives `preferredColorScheme` from the active palette.

**Tech Stack:** SwiftUI (iOS 17), Observation, UserDefaults. No XCTest suite (project convention); verification is `xcodebuild` + SwiftUI previews + manual theme switching.

**Build command (used throughout):**
```bash
cd /Users/prasta/Projects/personal/apps/active/psychopomp/psychopomp
xcodebuild -project Psychopomp.xcodeproj -scheme Psychopomp \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' build
```

**Commit note:** Commit steps reflect the intended cadence; confirm with the user before running them (their rule is "don't commit unless asked").

---

### Task 0: Feature branch

**Files:** none (git only)

- [ ] **Step 1: Create the branch**

```bash
cd /Users/prasta/Projects/personal/apps/active/psychopomp/psychopomp
git checkout -b feature/multi-theme
```

- [ ] **Step 2: Verify**

Run: `git branch --show-current`
Expected: `feature/multi-theme`

---

### Task 1: Palette, OrbStyle, ThemeID, and the five palettes

**Files:**
- Create: `Psychopomp/DesignSystem/Palette.swift`

- [ ] **Step 1: Create `Palette.swift`**

```swift
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
    case ethereal, traditionalDark, traditionalLight, catppuccinMocha, catppuccinLatte

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ethereal: return "Ethereal"
        case .traditionalDark: return "Dark"
        case .traditionalLight: return "Light"
        case .catppuccinMocha: return "Catppuccin Mocha"
        case .catppuccinLatte: return "Catppuccin Latte"
        }
    }

    var palette: Palette {
        switch self {
        case .ethereal: return .ethereal
        case .traditionalDark: return .traditionalDark
        case .traditionalLight: return .traditionalLight
        case .catppuccinMocha: return .catppuccinMocha
        case .catppuccinLatte: return .catppuccinLatte
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
}
```

- [ ] **Step 2: Build**

Run the build command. Expected: BUILD SUCCEEDED. (`Color(hex:)` already exists in `Theme.swift`.)

- [ ] **Step 3: Commit**

```bash
git add Psychopomp/DesignSystem/Palette.swift
git commit -m "feat(theme): add Palette, OrbStyle, ThemeID and five palettes"
```

---

### Task 2: ThemeManager (observable singleton)

**Files:**
- Create: `Psychopomp/DesignSystem/ThemeManager.swift`

- [ ] **Step 1: Create `ThemeManager.swift`**

```swift
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
```

- [ ] **Step 2: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Psychopomp/DesignSystem/ThemeManager.swift
git commit -m "feat(theme): add observable ThemeManager singleton with persistence"
```

---

### Task 3: Make `Theme.Color` resolve from the active palette

**Files:**
- Modify: `Psychopomp/DesignSystem/Theme.swift:12-60`

- [ ] **Step 1: Replace the `Color` enum body with computed accessors and add `Theme.orbStyle`**

Replace the entire `enum Color { … }` block (lines 12–60, from `enum Color {` through its closing `}`) with:

```swift
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
```

(Leave `Spacing`, `Radius`, `Font`, and the `extension Color { init(hex:) }` exactly as they are.)

- [ ] **Step 2: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Verify no visual change yet**

Run the app on the iPhone 16 simulator. Expected: identical to before (default theme is Ethereal). This confirms the indirection works before any new UI.

- [ ] **Step 4: Commit**

```bash
git add Psychopomp/DesignSystem/Theme.swift
git commit -m "refactor(theme): resolve Theme.Color from the active palette"
```

---

### Task 4: Drive the app's color scheme from the theme

**Files:**
- Modify: `Psychopomp/App/PsychopompApp.swift:6,19-27`

- [ ] **Step 1: Add the theme manager and wire `preferredColorScheme`**

Replace the `@State private var config = HermesConfig()` line with:

```swift
    @State private var config = HermesConfig()
    @State private var theme = ThemeManager.shared
```

Replace the `WindowGroup { … }` body with:

```swift
        WindowGroup {
            RootView()
                .environment(config)
                .environment(theme)
                .preferredColorScheme(theme.palette.colorScheme)
                .tint(Theme.Color.accent)
        }
```

- [ ] **Step 2: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Psychopomp/App/PsychopompApp.swift
git commit -m "feat(theme): drive preferredColorScheme + tint from the active theme"
```

---

### Task 5: Orb glow-vs-jewel render

**Files:**
- Modify: `Psychopomp/DesignSystem/OrbView.swift:63-89,200-216`

- [ ] **Step 1: Replace `coreBase` and `highlight` with theme-aware versions and add jewel helpers**

Replace the `coreBase` and `highlight` computed properties (the block from `private var coreBase: some View {` through the end of the `highlight` property) with:

```swift
    private var coreBase: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: coreColors,
                    center: UnitPoint(x: isJewel ? 0.40 : 0.48, y: isJewel ? 0.30 : 0.34),
                    startRadius: 2,
                    endRadius: diameter * 0.85
                )
            )
            .frame(width: diameter, height: diameter)
            .overlay { if isJewel { jewelRim } }
            .shadow(color: primaryShadow.color, radius: primaryShadow.radius, y: primaryShadow.y)
            .shadow(color: secondaryShadow.color, radius: secondaryShadow.radius, y: secondaryShadow.y)
    }

    /// Darkened rim that gives the jewel a convex, polished-stone depth.
    private var jewelRim: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.clear, .clear, .black.opacity(0.45)],
                    center: .center,
                    startRadius: diameter * 0.18,
                    endRadius: diameter * 0.5
                )
            )
            .frame(width: diameter, height: diameter)
            .blendMode(.multiply)
    }

    private var highlight: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white.opacity(state == .offline ? 0.15 : 0.55), .clear],
                    center: UnitPoint(x: 0.40, y: 0.30),
                    startRadius: 0,
                    endRadius: diameter * 0.34
                )
            )
            .frame(width: diameter, height: diameter)
    }
```

- [ ] **Step 2: Add the style helpers**

Immediately after the `highlight` property (before `// MARK: Layers`'s `swirlOverlay`, i.e. right after the closing `}` of `highlight`), add:

```swift
    /// Whether the active theme wants the dark-jewel render instead of the glow.
    private var isJewel: Bool { Theme.orbStyle == .jewel }

    /// Outer shadow pair: a soft aura bloom for glow themes, a grounding drop
    /// shadow for jewel themes.
    private var primaryShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        isJewel ? (.black.opacity(0.35), 18, 12) : (glowColor.opacity(glowOpacity), 38, 0)
    }

    private var secondaryShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        isJewel ? (.black.opacity(0.18), 40, 22) : (glowColor.opacity(glowOpacity * 0.5), 84, 0)
    }
```

- [ ] **Step 3: Add a jewel preview**

Replace the existing `#Preview("Orb states") { … }` block with:

```swift
#Preview("Orb states · Ethereal") {
    VStack(spacing: 40) {
        HStack(spacing: 40) {
            OrbView(state: .idle)
            OrbView(state: .listening, audioLevel: 0.8)
        }
        HStack(spacing: 40) {
            OrbView(state: .thinking)
            OrbView(state: .speaking)
        }
        OrbView(state: .offline)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .orbBackground()
}

#Preview("Orb jewel · Catppuccin Latte") {
    // Sets the shared theme for this preview process so the jewel render + light
    // canvas show. (Previews share the singleton; open one at a time.)
    ThemeManager.shared.selected = .catppuccinLatte
    return VStack(spacing: 40) {
        HStack(spacing: 40) {
            OrbView(state: .idle)
            OrbView(state: .listening, audioLevel: 0.8)
        }
        OrbView(state: .speaking)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .orbBackground()
}
```

- [ ] **Step 4: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Verify previews**

Open `OrbView.swift` canvas. Expected: the Ethereal preview is unchanged (glowing). The Latte preview shows a **dark jewel** orb (deep mauve stone, bright specular, grounding shadow) on a light background. (If both previews are open, the singleton means the last one set wins — view them one at a time.)

- [ ] **Step 6: Commit**

```bash
git add Psychopomp/DesignSystem/OrbView.swift
git commit -m "feat(orb): dark-jewel render for light themes; glow for dark"
```

---

### Task 6: Theme picker in Settings

**Files:**
- Modify: `Psychopomp/Features/Settings/SettingsView.swift:5-12,23-35`

- [ ] **Step 1: Add the theme manager binding**

After the existing `@Environment(\.dismiss) private var dismiss` line, add:

```swift
    @Bindable private var theme = ThemeManager.shared
```

- [ ] **Step 2: Add an Appearance section**

In `body`, immediately after the closing `}` of the `group("Default model") { … }` block (and before the `if let status {` line), add:

```swift
                group("Appearance") {
                    Picker("Theme", selection: $theme.selected) {
                        ForEach(ThemeID.allCases) { id in
                            Text(id.displayName).tag(id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Color.aura)
                }
```

- [ ] **Step 3: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Psychopomp/Features/Settings/SettingsView.swift
git commit -m "feat(settings): add Appearance theme picker"
```

---

### Task 7: Manual verification across all five themes

**Files:** none (verification); optional `Psychopomp/App/PsychopompApp.swift` if the safety net is needed.

- [ ] **Step 1: Build & run, then switch every theme**

Run on the iPhone 16 simulator. Open Settings → Appearance and select each theme in turn. Confirm for each:
- Orb home recolors (background, orb, text, accents).
- The full chat transcript (`ChatView`) and Settings recolor too.
- **Light themes (Traditional Light, Catppuccin Latte):** the orb shows the dark jewel, system chrome (keyboard, pickers, scrollbars) flips to light, text stays legible.
- **Dark themes:** the orb glows in that theme's hue.
- Selection persists across an app relaunch.

- [ ] **Step 2: (Only if a view fails to update live) add the root rebuild safety net**

If any screen doesn't recolor until navigated away and back, in `PsychopompApp.swift` add `.id(theme.selected)` to `RootView()` (after `.tint(...)`):

```swift
            RootView()
                .environment(config)
                .environment(theme)
                .preferredColorScheme(theme.palette.colorScheme)
                .tint(Theme.Color.accent)
                .id(theme.selected)
```

Rebuild and re-verify. If everything already updated live in Step 1, skip this step.

- [ ] **Step 3: Commit (only if Step 2 was needed)**

```bash
git add Psychopomp/App/PsychopompApp.swift
git commit -m "fix(theme): force root rebuild on theme switch"
```

---

## Notes

- **No consuming views change.** `Composer`, `ChatView`, `MessageRow`, `MarkdownText`, `ToolProgressView`, `ApprovalSheet`, `ConnectionView`, `ConversationListView`, `RecentSessionsSheet`, `OrbHomeView`, `Components`, `TerminalText` all keep using `Theme.Color.*` unchanged and recolor automatically.
- **Catppuccin** values are the project's published Latte/Mocha flavor hex codes.
- **Previews + the singleton:** because `ThemeManager` is a singleton, multi-theme previews share one selection. The jewel preview sets `.catppuccinLatte`; view previews one at a time. In-app switching is the real verification.
