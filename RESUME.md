# Resume notes — Psychopomp

_Last updated: 2026-06-27_

Quick handoff of what's in flight so work can pick up cleanly.

## Active work: multi-theme system (branch `feature/multi-theme`)

Adds 5 runtime-switchable themes (Ethereal default, Traditional Dark, Traditional
Light, Catppuccin Mocha, Catppuccin Latte). Orb glows on dark themes, renders as a
dark jewel on light themes.

- **Spec:** `docs/superpowers/specs/2026-06-26-theming-design.md`
- **Plan:** `docs/superpowers/plans/2026-06-26-multi-theme.md`

### Committed on the branch (build-verified)
- T0 branch + plan
- T1 `DesignSystem/Palette.swift` (Palette, OrbStyle, ThemeID, 5 palettes; `Color(hex:)` now takes `Int`)
- T2 `DesignSystem/ThemeManager.swift` (@Observable singleton, persists `theme.selected`)
- T3 `DesignSystem/Theme.swift` — `Theme.Color.*` now resolve from the active palette; added `Theme.orbStyle`
- T4 `App/PsychopompApp.swift` — drives `preferredColorScheme`/`tint` from the theme
- T5 `DesignSystem/OrbView.swift` — glow vs dark-jewel render

### OUTSTANDING

1. **T6 theme picker — written & builds, but NOT committed.** The Appearance picker
   lives in `Features/Settings/SettingsView.swift`, which ALSO contains the
   in-progress Apple Intelligence provider section. Couldn't split them in one file
   non-interactively, so it was left uncommitted to avoid bundling AI WIP under a
   theming commit. **Do not discard `SettingsView.swift`** — the picker exists only
   in the working tree.
   - Decision needed on resume: **(A)** commit `SettingsView.swift` whole with an
     honest message covering both changes, or **(B)** commit it alongside the Apple
     Intelligence work.

2. **T7 verification — partial.** Verified Ethereal (default) and Catppuccin Latte
   (light + dark-jewel orb + status-bar flip). Not yet screenshot-checked: Traditional
   Dark, Traditional Light, Catppuccin Mocha — they share the proven glow/jewel path;
   switch them live via Settings → Appearance.

## Parallel WIP (not mine — user's, do not commit without asking)

- `Networking/AppleIntelligenceClient.swift` (staged) — on-device Foundation Models
  client. Had a build error (`Snapshot.count`); fix is to read `partial.content`.
- `Networking/HermesConfig.swift` (staged) — adds `useAppleIntelligence` /
  `appleIntelligenceClient`.
- `Features/Settings/SettingsView.swift` — adds the AI-provider toggle section.

## Repo state
- Build is **green**.
- **Nothing pushed.** Both `main` and `feature/multi-theme` are ahead of `origin`.
- Earlier this session, the **orb voice home + polish** was completed and **merged to
  `main`** (separate from the theming branch).
- Simulator note: the iPhone 16 sim's stored `theme.selected` was set to
  `catppuccinLatte` during testing (sim-only state, not a code default; default is
  Ethereal).

## To resume
Say **"resume theming"** → settle the T6 commit (A or B), finish T7.
