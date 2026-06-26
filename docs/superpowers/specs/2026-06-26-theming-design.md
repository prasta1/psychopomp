# Psychopomp — Multi-Theme System Design

**Date:** 2026-06-26
**Status:** Approved (design), pending implementation plan

## Summary

Add a runtime-switchable theme system with **five themes**: Ethereal (default),
Traditional Dark, Traditional Light, Catppuccin Mocha (dark), and Catppuccin Latte
(light). The user picks a theme in Settings; the whole UI recolors live. The
glowing orb keeps its luminous render on the three dark themes and switches to a
**dark-jewel** render (a deep polished stone with a bright specular) on the two
light themes, where a glow reads weak.

## Goals

- Five selectable themes, persisted across launches; default Ethereal.
- Live switching — no relaunch.
- **Minimal churn:** keep the existing `Theme.Color.X` API so the ~150 call sites
  across 15 views are untouched.
- The orb stays beautiful in every theme (glow on dark, jewel on light).

## Non-goals

- Custom/user-authored themes or color editing.
- Per-screen theme overrides.
- Animated cross-fade between themes (a normal SwiftUI transition is fine; no bespoke morph).
- Changing the orb's gesture, animation timing, or layout — only its colors and the
  glow-vs-jewel render path.

## Architecture

Themes switch **without touching consuming views**. The trick: keep every existing
`Theme.Color.<name>` token, but change it from a `static let` constant into a
`static var` computed from the active palette.

- **`Palette`** — a value type holding every existing color role (same names as
  today) plus `orbStyle` and `colorScheme`.
- **`ThemeManager`** — an `@Observable` singleton (`ThemeManager.shared`) holding the
  selected `ThemeID`, persisting it to `UserDefaults`, and exposing the current
  `palette`.
- **`Theme.Color.<name>`** — now `static var name: Color { ThemeManager.shared.palette.name }`.
  Because `ThemeManager` is `@Observable` and these reads happen during each view's
  `body`, SwiftUI Observation tracks them and re-renders on switch. No `.environment`
  threading, no per-view edits.

*Rejected alternative:* inject a `Palette` through the SwiftUI environment and rewrite
every `Theme.Color.X` → `palette.x`. Cleaner in theory, but edits all 15 files and
threads environment everywhere — disproportionate churn for this codebase.

### Safety net
If any view fails to observe the change (e.g. a cached subview), apply
`.id(ThemeManager.shared.selected)` to the root view so a theme switch forces a full
rebuild. Implement first *without* it; add only if a view doesn't update.

## Components

| Unit | Responsibility |
|---|---|
| `Palette` (struct) | One value per color role + `orbStyle: OrbStyle` + `colorScheme: ColorScheme`. Pure data. |
| `OrbStyle` (enum) | `.glow` (dark themes) or `.jewel` (light themes). |
| `ThemeID` (enum) | `.ethereal, .traditionalDark, .traditionalLight, .catppuccinMocha, .catppuccinLatte`; each maps to a `Palette` + a display name. |
| `ThemeManager` (@Observable singleton) | Holds `selected: ThemeID` (persisted), exposes `palette: Palette`. |
| `Theme.Color.*` | Unchanged names, now computed from `ThemeManager.shared.palette`. Also expose `Theme.orbStyle`. |
| `OrbView` | Branches on `Theme.orbStyle`: `.glow` = today's render; `.jewel` = dark stone with specular + inner-shadow depth, no bloom. Reads orb stops + glow from `Theme.Color`. |
| `SettingsView` | New "Appearance" section: a picker over the five themes. |
| `PsychopompApp` | Holds `@State theme = ThemeManager.shared`, injects it, replaces `.preferredColorScheme(.dark)` with `theme.palette.colorScheme`. |

## Color roles (the `Palette` fields)

Existing names kept verbatim so views don't change:
`bg, canvas, canvasTop, surface, raised, border,
textPrimary, textSecondary, textDim, textCool, textCoolDim, textCoolFaint,
accent, aura, aura2, green, red,
orbHighlight, orbMid, orbDeep, orbCore, orbOffline`
plus `orbStyle` and `colorScheme`.

(Note: the existing terminal set and ethereal set both survive as roles; a theme may
set, e.g., `textPrimary` and `textCool` to the same value.)

## Palettes (hex)

Catppuccin values are the project's published Latte/Mocha flavor colors.

### Ethereal (default · dark · glow) — unchanged from today
bg `#0B0B0C` · canvas `#070912` · canvasTop `#0E1424` · surface `#161618` · raised `#1E1E21` · border `#2A2A2E`
textPrimary `#E9E6DF` · textSecondary `#9A968C` · textDim `#5E5B54`
textCool `#DCE8FF` · textCoolDim `#7E8BB5` · textCoolFaint `#566190`
accent `#CDB089` · aura `#7C96FF` · aura2 `#9678FF` · green `#7FB89B` · red `#C8736B`
orbHighlight `#EEF9FF` · orbMid `#ACD6FF` · orbDeep `#6F7CFF` · orbCore `#241A3A` · orbOffline `#4A4E63`

### Traditional Dark (dark · glow · system blue)
bg `#000000` · canvas `#0A0A0B` · canvasTop `#141416` · surface `#1C1C1E` · raised `#2C2C2E` · border `#38383A`
textPrimary `#FFFFFF` · textSecondary `#AEAEB2` · textDim `#636366`
textCool `#FFFFFF` · textCoolDim `#AEAEB2` · textCoolFaint `#636366`
accent `#0A84FF` · aura `#0A84FF` · aura2 `#5E9EFF` · green `#30D158` · red `#FF453A`
orbHighlight `#DCE9FF` · orbMid `#5EA2FF` · orbDeep `#0A84FF` · orbCore `#0A2A55` · orbOffline `#48484A`

### Traditional Light (light · jewel · system blue)
bg `#FFFFFF` · canvas `#F2F2F7` · canvasTop `#FFFFFF` · surface `#FFFFFF` · raised `#F2F2F7` · border `#D1D1D6`
textPrimary `#1C1C1E` · textSecondary `#3A3A3C` · textDim `#8E8E93`
textCool `#1C1C1E` · textCoolDim `#3A3A3C` · textCoolFaint `#8E8E93`
accent `#007AFF` · aura `#007AFF` · aura2 `#5E9EFF` · green `#34C759` · red `#FF3B30`
orb (dark jewel) — orbHighlight `#CFE0FF` (specular) · orbMid `#3D5FA8` · orbDeep `#20305C` · orbCore `#0C1730` · orbOffline `#C7C7CC`

### Catppuccin Mocha (dark · glow)
bg `#1E1E2E` · canvas `#181825` · canvasTop `#1E1E2E` · surface `#313244` · raised `#45475A` · border `#45475A`
textPrimary `#CDD6F4` · textSecondary `#A6ADC8` · textDim `#6C7086`
textCool `#CDD6F4` · textCoolDim `#A6ADC8` · textCoolFaint `#6C7086`
accent `#CBA6F7` (mauve) · aura `#89B4FA` (blue) · aura2 `#B4BEFE` (lavender) · green `#A6E3A1` · red `#F38BA8`
orbHighlight `#F0E9FF` · orbMid `#CBA6F7` · orbDeep `#89B4FA` · orbCore `#45456B` · orbOffline `#6C7086`

### Catppuccin Latte (light · jewel)
bg `#EFF1F5` · canvas `#E6E9EF` · canvasTop `#EFF1F5` · surface `#E6E9EF` · raised `#DCE0E8` · border `#CCD0DA`
textPrimary `#4C4F69` · textSecondary `#6C6F85` · textDim `#9CA0B0`
textCool `#4C4F69` · textCoolDim `#6C6F85` · textCoolFaint `#9CA0B0`
accent `#8839EF` (mauve) · aura `#8839EF` · aura2 `#7287FD` (lavender) · green `#40A02B` · red `#D20F39`
orb (dark jewel) — orbHighlight `#D9C4F5` (specular) · orbMid `#6B4BA0` · orbDeep `#36285C` · orbCore `#1E1B2E` · orbOffline `#9CA0B0`

## Orb render: glow vs jewel

`OrbView` reads `Theme.orbStyle` and branches:

- **`.glow`** (Ethereal, Traditional Dark, Mocha): the current render — radial-gradient
  sphere (orbHighlight→orbMid→orbDeep→orbCore), two soft `aura` glow shadows,
  PhaseAnimator breath. Unchanged.
- **`.jewel`** (Traditional Light, Latte): a deep polished stone. Same gradient stops
  (which are now dark), but instead of bloom shadows:
  - a grounding **drop shadow** (dark, offset down) so it sits on the light page,
  - an **inner-shadow rim** (an overlaid radial gradient: clear center → dark edge) for
    convex depth,
  - a small bright **specular** highlight near the top-left (the existing `highlight`
    layer, using `orbHighlight`).
  Breath/scale and ripples still apply; the listening ripples use `aura` (the accent),
  which is visible on a light background.

## Data flow

Settings picker sets `ThemeManager.shared.selected` → `didSet` persists to UserDefaults
→ `@Observable` invalidates every view reading `Theme.Color.*` / `Theme.orbStyle` →
UI recolors; the app root re-applies `palette.colorScheme` so system chrome (keyboard,
pickers, scrollbars) flips light/dark for the two light themes.

## Error handling

Presentation-only; no failure surfaces. On first launch (or an unknown stored value),
`ThemeManager` falls back to `.ethereal`.

## Testing & verification

- **SwiftUI previews:** an `OrbView` preview matrix (each `ThemeID`) to confirm glow vs
  jewel; ideally a Settings preview per theme.
- **Build:** `xcodebuild -project Psychopomp.xcodeproj -scheme Psychopomp
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' build`.
- **Manual:** switch each theme in Settings and confirm the home, chat transcript,
  and Settings all recolor; confirm light themes flip system chrome and show the jewel orb.

## Suggested build order

1. `Palette` + `OrbStyle` + `ThemeID` (data only) with the five palettes.
2. `ThemeManager` (@Observable singleton, persistence).
3. Convert `Theme.Color` lets → computed vars; add `Theme.orbStyle`. Build (UI still
   Ethereal-only, should look identical).
4. Wire `PsychopompApp`: inject manager, drive `preferredColorScheme`.
5. `OrbView` jewel branch + per-theme preview matrix.
6. `SettingsView` Appearance picker.
7. Manual pass across all five themes; add root `.id` only if a view fails to update.
