# Psychopomp — Orb Voice Home Redesign

**Date:** 2026-06-26
**Status:** Approved (design), pending implementation plan

## Summary

Replace the current conversation-list home screen with a **glowing orb** that is
the app's centerpiece and primary push-to-talk interface to the Hermes agent. The
orb is voice-first: hold it to speak, release to send, and the agent's reply
streams in as text beneath it. Conversation history, the full rich-text transcript,
and the keyboard all remain available but are tucked behind subtle affordances.

The visual direction is **"Ethereal Wisp"** — a cool luminous core with a
violet/cyan aura on a deep indigo-black canvas — leaning into the app's name
(*psychopomp*, a guide of souls).

## Goals

- Make the orb the first thing the user sees and the main way they interact.
- A calm, elegant, "alive" motion language that communicates state at a glance.
- Voice-first, but never trap the user — keyboard and rich transcript always reachable.
- Reuse the existing networking, streaming, persistence, and voice plumbing.

## Non-goals (out of scope for this pass)

- Text-to-speech / spoken replies (designed-for as an *optional toggle* later; no
  hard dependency now).
- A full re-theme of Settings / Connection screens (they inherit the new palette
  where cheap, but no structural redesign).
- Conversation branching, background jobs, push — all still roadmap items.

## Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| App structure | Orb is the new **home**. History + full text chat tucked behind affordances. Voice-first, keyboard always reachable. |
| Reply mode | Reply **streams as text under the orb**. Orb stays the hero. Tool steps shown as subtle chips. Speak-aloud is a future optional toggle — no TTS dependency now. |
| PTT gesture | **Hold OR tap-lock.** Hold the orb to talk (release to send); a short tap latches hands-free listening until tapped again. |
| Visual direction | **Ethereal Wisp** — cool luminous core, violet/cyan aura, faint orbit ring, soft sans, deep indigo-black background. |
| History access | **Swipe-up bottom sheet** ("Recent sessions"), thumb-reachable. |

## Motion language (orb states)

A single `OrbState` drives all visuals:

- **idle** — slow ~5s "breath", dimmer glow, faint orbit ring. Caption "Hold to speak".
- **listening** — brighter, faster breath, concentric ripples pushing outward
  (ripple intensity reacts to live mic audio level). Caption "Listening…", live
  partial transcript shown faintly.
- **thinking** — internal energy swirl churns (rotating conic gradient under the
  core highlight). Caption "Thinking…".
- **speaking** — quick rhythmic pulse while reply text streams in below. Caption
  is the agent name; streaming cursor at text tail.
- **offline / error** — desaturated grey-violet, breathing stops, "tap to
  reconnect" hint.

## Screen layout

- **Idle:** orb dead-center. Caption + hint below ("tap to lock hands-free · ⌨ to type").
- **Replying:** orb lifts toward the top and shrinks into its `speaking` state; the
  reply streams as text below it, with subtle tool-activity chips
  (e.g. `⏵ terminal · pytest -k auth`) and a blinking cursor.
- **Chrome:** connection status + model name top-left; settings gear top-right;
  stop button bottom-left (only during a run); keyboard toggle bottom-right;
  bottom-center grabber labeled "Recent sessions" (swipe up).

## Architecture

The redesign is mostly **new presentation** over **existing plumbing**. Reused as-is:
`HermesClient`, `HermesConfig`, `ChatViewModel` (streaming state machine),
`VoiceRecorder`, the SwiftData models (`Conversation`, `ChatMessage`, `ToolEvent`,
`Attachment`), `SSEParser`/`RunEvent`, and the existing full-transcript `ChatView`
(retained for rich/long output and reading history).

### New / changed units

Each unit has one clear job and a narrow interface so it can be understood, previewed,
and changed in isolation.

1. **`OrbState` (enum)** — `idle | listening | thinking | speaking | offline`.
   The single source of truth for what the orb shows.

2. **`OrbView` (DesignSystem component)** — *pure visual*. Inputs: an `OrbState`
   and an optional `audioLevel: Float` (0–1) for listening reactivity. Knows
   nothing about networking, speech, or SwiftData. Drives all gradients, glow,
   breath, ripples, and the swirl. Fully exercisable via SwiftUI previews (one
   per state). This is the reusable heart of the redesign.

3. **`OrbHomeView` (new root home)** — orchestration. Responsibilities:
   - Owns the current `Conversation` and a `ChatViewModel` for it.
   - Hosts the orb gesture: hold-to-talk and short-tap-to-lock (hands-free).
   - Drives `VoiceRecorder` (auth, start, stop) and maps
     recorder + view-model status → `OrbState`.
   - On a non-empty final transcript, calls `viewModel.send(text:)`.
   - Renders the current turn beneath the orb (streaming reply text + tool chips)
     and the chrome affordances. Tapping the reply expands into `ChatView`.

4. **`RecentSessionsSheet` (new)** — the swipe-up bottom sheet. Lists conversations
   (reusing the existing row style), lets the user switch the current session,
   open the full `ChatView`, start a new session, or delete. Folds in the useful
   parts of today's `ConversationListView`.

5. **`Theme` additions** — an "ethereal" palette: orb core/aura gradient stops,
   the deep-indigo canvas, cool text colors, and a soft sans display font
   alongside the existing monospace tokens. The orb home and the transcript
   surface adopt these; secondary screens inherit only where trivial.

6. **`VoiceRecorder` extension (optional, for ripple reactivity)** — expose a
   smoothed `audioLevel` computed from the existing input tap buffer (RMS). If we
   skip it, ripples animate on a fixed cadence instead. Non-blocking.

7. **`RootView` change** — route to `OrbHomeView` instead of `ConversationListView`
   once configured.

### Conversation continuity

The orb home binds to a **current conversation**. Repeated utterances continue the
same session (preserving the agent's per-session memory via
`X-Hermes-Session-Key`), so you can hold → speak → listen → hold again for a real
back-and-forth. "New session" is available from the Recent sheet (and/or a small
new-session control). Opening the full `ChatView` shows the complete rich
transcript for the current conversation.

## Data flow (one turn)

1. Hold orb → request mic/speech auth → `VoiceRecorder.start()` → `OrbState = .listening`;
   faint live partial transcript; ripples react to `audioLevel`.
2. Release (or tap when locked) → `VoiceRecorder.stop()` → final transcript.
   Empty → no-op. Non-empty → `viewModel.send(text:)` → `OrbState = .thinking`.
3. Stream events arrive; first `textDelta` → `OrbState = .speaking`; reply text
   accumulates under the orb; `ToolEvent`s render as subtle chips.
4. Completion → brief beat → `OrbState = .idle` (last reply stays visible until the
   next interaction).
5. Keyboard toggle → compact text entry → same `send` pipeline.
6. Swipe up → `RecentSessionsSheet` → switch/open/new.

## Error handling (only where it matters — boundaries)

- **Permission denied** (mic/speech): orb shows a one-line hint and routes the user
  to the keyboard; no crash, no silent failure.
- **Recognizer unavailable / not configured**: `OrbState = .offline` with a
  "tap to reconnect / open settings" hint.
- **Network / stream errors**: handled by the existing `ChatViewModel` path; the
  error surfaces briefly beneath the orb (and in full in `ChatView`).
- **Empty transcript on release**: ignored.

## Testing & verification

The project has no test suite today, and per project conventions we won't add one
unprompted. Verification is:

- **SwiftUI previews** for `OrbView` — one per `OrbState` — to iterate on the
  motion without running the whole app.
- **Build verification**: `xcodebuild -project Psychopomp.xcodeproj -scheme
  Psychopomp -destination 'platform=iOS Simulator,name=iPhone 16' build`.
- **Manual**: hold/tap-lock a turn end-to-end against a running Hermes agent.

## Suggested build order (for the plan)

1. `OrbState` + `OrbView` with previews (visual core, no dependencies).
2. `Theme` ethereal palette tokens.
3. `OrbHomeView` shell — orb centered, gesture, state mapping, wire `VoiceRecorder`
   + `ChatViewModel`; streaming reply text under the orb.
4. `RecentSessionsSheet` + chrome affordances; route `RootView` to `OrbHomeView`.
5. Polish: audio-reactive ripples, tap-lock hands-free, expand-to-`ChatView`,
   offline state.
