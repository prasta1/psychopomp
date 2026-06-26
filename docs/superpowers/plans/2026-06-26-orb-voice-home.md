# Orb Voice Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the conversation-list home with a glowing "Ethereal Wisp" orb that is the primary push-to-talk interface; the agent's reply streams as text beneath it.

**Architecture:** New SwiftUI presentation layer (`OrbView` pure-visual component + `OrbHomeView` orchestrator + `RecentSessionsSheet`) over the existing, unchanged plumbing (`HermesClient`, `ChatViewModel`, `VoiceRecorder`, SwiftData models). A single `OrbState` enum drives all orb visuals. `RootView` routes to `OrbHomeView`.

**Tech Stack:** SwiftUI (iOS 17), SwiftData, Observation, AVFoundation + Speech (existing `VoiceRecorder`). Verification is via SwiftUI previews + `xcodebuild` (project has no unit-test suite, and per project convention we don't add one here).

**Verification note:** This project has no XCTest target and the user's conventions say don't add tests unprompted. So each task's "verify" step is a **build** (and, for `OrbView`, **previews**), not a unit test. Build command used throughout:

```bash
cd /Users/prasta/Projects/personal/apps/active/psychopomp/psychopomp
xcodebuild -project Psychopomp.xcodeproj -scheme Psychopomp \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Commit note:** The user's global rule is "don't commit unless explicitly asked." Commit steps are included below as the intended cadence, but at execution time confirm with the user before running them (or batch them).

---

### Task 0: Feature branch

**Files:** none (git only)

- [ ] **Step 1: Create and switch to the feature branch**

```bash
cd /Users/prasta/Projects/personal/apps/active/psychopomp/psychopomp
git checkout -b feature/orb-voice-home
```

- [ ] **Step 2: Verify**

Run: `git branch --show-current`
Expected: `feature/orb-voice-home`

---

### Task 1: Ethereal palette + sans typography (Theme)

**Files:**
- Modify: `Psychopomp/DesignSystem/Theme.swift`

- [ ] **Step 1: Add ethereal color tokens**

In `Theme.Color`, add these after the existing `red` token (keep all existing tokens — other screens still use them):

```swift
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
```

- [ ] **Step 2: Add soft-sans font tokens**

In `Theme.Font`, add after `code`:

```swift
        // Soft sans for the orb home (a calmer counterpoint to the mono UI).
        static let sansTitle = SwiftUI.Font.system(.title3, design: .default).weight(.medium)
        static let sansBody = SwiftUI.Font.system(.body, design: .default)
        static let sansCaption = SwiftUI.Font.system(.caption, design: .default)
```

- [ ] **Step 3: Add an ethereal screen-background helper**

At the bottom of `Theme.swift`, extend the existing `View` convenience (add a new method; do not remove `screenBackground()`):

```swift
extension View {
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
```

- [ ] **Step 4: Build**

Run the build command above.
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Psychopomp/DesignSystem/Theme.swift
git commit -m "feat(theme): add ethereal orb palette and sans tokens"
```

---

### Task 2: OrbState + OrbView (pure visual) with previews

**Files:**
- Create: `Psychopomp/DesignSystem/OrbView.swift`

This is the reusable heart of the redesign — no networking, no speech. Validate it in previews.

- [ ] **Step 1: Create `OrbView.swift` with the state enum, component, and previews**

```swift
import SwiftUI

/// The single source of truth for what the orb is depicting.
enum OrbState: Equatable {
    case idle        // resting, waiting for input
    case listening   // recording the user's voice
    case thinking    // run started, no text yet
    case speaking    // reply text streaming in
    case offline     // not configured / unreachable
}

/// The animated "Ethereal Wisp" orb — the app's centerpiece and push-to-talk surface.
///
/// Pure visual: it renders gradient, glow, breath, ripples and the thinking swirl
/// based solely on `state` and `audioLevel`, so it can be exercised entirely in
/// previews. It honors Reduce Motion by holding still.
struct OrbView: View {
    /// What the orb should depict.
    var state: OrbState
    /// Live mic level 0...1; intensifies ripples while `.listening`.
    var audioLevel: Double = 0

    @State private var breathing = false
    @State private var swirling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let diameter: CGFloat = 108

    var body: some View {
        ZStack {
            if state == .listening { ripples }
            coreBase
            if state == .thinking { swirlOverlay }
            highlight
        }
        .frame(width: 140, height: 140)
        .scaleEffect(breathScale)
        .animation(breathAnimation, value: breathing)
        .animation(.easeInOut(duration: 0.45), value: state)
        .onAppear { breathing = true; swirling = true }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Layers

    private var coreBase: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: coreColors,
                    center: UnitPoint(x: 0.48, y: 0.34),
                    startRadius: 2,
                    endRadius: diameter * 0.85
                )
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: glowColor.opacity(glowOpacity), radius: 28)
            .shadow(color: glowColor.opacity(glowOpacity * 0.5), radius: 64)
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

    private var swirlOverlay: some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: [Theme.Color.orbDeep, Theme.Color.orbMid,
                             Theme.Color.aura2, Theme.Color.orbDeep],
                    center: .center
                )
            )
            .frame(width: diameter * 1.4, height: diameter * 1.4)
            .blur(radius: 12)
            .opacity(0.6)
            .rotationEffect(.degrees(swirling && !reduceMotion ? 360 : 0))
            .animation(reduceMotion ? nil : .linear(duration: 5.5).repeatForever(autoreverses: false),
                       value: swirling)
            .mask(Circle().frame(width: diameter, height: diameter))
            .blendMode(.plusLighter)
    }

    private var ripples: some View {
        ZStack {
            Ripple(delay: 0.0, intensity: rippleIntensity, base: diameter)
            Ripple(delay: 0.8, intensity: rippleIntensity, base: diameter)
            Ripple(delay: 1.6, intensity: rippleIntensity, base: diameter)
        }
    }

    // MARK: Derived style

    private var coreColors: [Color] {
        switch state {
        case .offline:
            return [Theme.Color.orbOffline.opacity(0.9), Theme.Color.orbOffline,
                    Theme.Color.orbCore, Theme.Color.canvas]
        default:
            return [Theme.Color.orbHighlight, Theme.Color.orbMid,
                    Theme.Color.orbDeep, Theme.Color.orbCore]
        }
    }

    private var glowColor: Color { state == .offline ? Theme.Color.orbOffline : Theme.Color.aura }

    private var glowOpacity: Double {
        switch state {
        case .idle: return 0.30
        case .listening: return 0.55
        case .thinking: return 0.42
        case .speaking: return 0.50
        case .offline: return 0.12
        }
    }

    private var breathScale: CGFloat {
        guard breathing, !reduceMotion, state != .offline else { return 1.0 }
        switch state {
        case .listening, .speaking: return 1.08
        case .thinking: return 1.04
        default: return 1.05
        }
    }

    private var breathAnimation: Animation? {
        guard !reduceMotion, state != .offline else { return nil }
        let duration: Double
        switch state {
        case .idle: duration = 5.0
        case .listening: duration = 2.1
        case .thinking: duration = 3.4
        case .speaking: duration = 1.5
        case .offline: duration = 0
        }
        return .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }

    private var rippleIntensity: Double { 0.5 + min(audioLevel, 1.0) * 0.5 }

    private var accessibilityLabel: String {
        switch state {
        case .idle: return "Orb. Idle. Hold to speak."
        case .listening: return "Orb. Listening."
        case .thinking: return "Orb. Thinking."
        case .speaking: return "Orb. Replying."
        case .offline: return "Orb. Offline."
        }
    }
}

/// One expanding ring used by the listening ripples.
private struct Ripple: View {
    let delay: Double
    let intensity: Double
    let base: CGFloat
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .stroke(Theme.Color.aura.opacity(0.5 * intensity), lineWidth: 1.5)
            .frame(width: base, height: base)
            .scaleEffect(animate ? 2.2 : 0.6)
            .opacity(animate ? 0 : 0.5)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(delay)) {
                    animate = true
                }
            }
    }
}

#Preview("Orb states") {
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
```

- [ ] **Step 2: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Verify previews**

In Xcode, open `OrbView.swift` and resume the canvas. Expected: all five states render; idle breathes slowly, listening shows ripples, thinking swirls, speaking pulses fast, offline is a dim static grey-violet sphere. (Tell the user to glance at the canvas.)

- [ ] **Step 4: Commit**

```bash
git add Psychopomp/DesignSystem/OrbView.swift
git commit -m "feat(orb): add OrbState and animated OrbView with previews"
```

---

### Task 3: Mic audio level for ripple reactivity (VoiceRecorder)

**Files:**
- Modify: `Psychopomp/Features/Chat/VoiceRecorder.swift`

- [ ] **Step 1: Add a smoothed `level` property**

After the line `private(set) var transcript = ""` add:

```swift
    /// Smoothed microphone level (0...1) for live UI reactivity (e.g. orb ripples).
    private(set) var level: Double = 0
```

- [ ] **Step 2: Compute level in the input tap**

In `start()`, replace the existing tap installation:

```swift
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
```

with:

```swift
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.ingest(buffer)
        }
```

- [ ] **Step 3: Add the level helpers**

In the `// MARK: - Private` section, add:

```swift
    /// Computes RMS amplitude off the audio thread and smooths it onto the main actor.
    nonisolated private func ingest(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }
        var sum: Float = 0
        for i in 0..<count { let s = channel[i]; sum += s * s }
        let rms = (sum / Float(count)).squareRoot()
        let normalized = min(1.0, Double(rms) * 12.0)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.level = self.level * 0.7 + normalized * 0.3
        }
    }
```

- [ ] **Step 4: Reset level on stop**

In `stop()`, after `isRecording = false` add:

```swift
        level = 0
```

- [ ] **Step 5: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Psychopomp/Features/Chat/VoiceRecorder.swift
git commit -m "feat(voice): expose smoothed mic level for orb ripples"
```

---

### Task 4: OrbHomeView core (orb + gesture + voice loop + reply) and route the app to it

**Files:**
- Create: `Psychopomp/Features/Orb/OrbHomeView.swift`
- Modify: `Psychopomp/App/PsychopompApp.swift:38-44`

- [ ] **Step 1: Create `OrbHomeView.swift`**

```swift
import SwiftUI
import SwiftData

/// The orb home — the app's primary surface. Hold the orb to talk (release to send),
/// or tap to latch hands-free listening. The agent's reply streams as text below it.
/// History, the full transcript, and the keyboard remain reachable.
struct OrbHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HermesConfig.self) private var config

    /// The conversation the orb is currently bound to (continued across turns).
    @State private var conversation: Conversation?
    @State private var viewModel: ChatViewModel?
    @State private var recorder = VoiceRecorder()

    @State private var path: [Conversation] = []
    @State private var liveTranscript = ""
    @State private var isLocked = false
    @State private var pressStartedAt: Date?
    @State private var permissionDenied = false
    @State private var showRecent = false
    @State private var showSettings = false
    @State private var showKeyboard = false
    @State private var keyboardDraft = ""
    @State private var models: [HermesModelInfo] = []

    /// Below which a press counts as a "tap" (latch) rather than a "hold" (send).
    private let tapThreshold: TimeInterval = 0.4

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                orbStage
                chrome
            }
            .orbBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Conversation.self) { ChatView(conversation: $0) }
            .sheet(isPresented: $showRecent) {
                RecentSessionsSheet(
                    current: conversation,
                    onSelect: { select($0) },
                    onOpen: { showRecent = false; path.append($0) },
                    onNew: { startNewSession() }
                )
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .task { await loadModels() }
            .onChange(of: recorder.transcript) { _, new in
                if recorder.isRecording { liveTranscript = new }
            }
        }
        .tint(Theme.Color.aura)
    }

    // MARK: - Orb + current turn

    private var orbStage: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer(minLength: 0)
            OrbView(state: orbState, audioLevel: recorder.level)
                .contentShape(Circle())
                .gesture(orbGesture)
            caption
            replyArea
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, 96)
    }

    private var caption: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(captionText)
                .font(Theme.Font.sansTitle)
                .foregroundStyle(Theme.Color.textCool)
            if orbState == .idle {
                Text("tap to lock hands-free")
                    .font(Theme.Font.sansCaption)
                    .foregroundStyle(Theme.Color.textCoolFaint)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: orbState)
    }

    @ViewBuilder
    private var replyArea: some View {
        if recorder.isRecording, !liveTranscript.isEmpty {
            Text(liveTranscript)
                .font(Theme.Font.sansBody)
                .foregroundStyle(Theme.Color.textCoolDim)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .transition(.opacity)
        } else if let assistant = latestAssistant, !assistant.text.isEmpty {
            Button { path.append(conversation!) } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(assistant.text)
                        .font(Theme.Font.sansBody)
                        .foregroundStyle(Theme.Color.textCool)
                        .multilineTextAlignment(.leading)
                        .lineLimit(8)
                    ForEach(assistant.orderedToolEvents) { event in
                        toolChip(event)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func toolChip(_ event: ToolEvent) -> some View {
        Text("\u{25B7} \(event.name)\(event.detail.isEmpty ? "" : " \u{00B7} \(event.detail)")")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.aura)
            .lineLimit(1)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(Theme.Color.aura.opacity(0.12), in: Capsule())
    }

    // MARK: - Chrome (status, settings, keyboard, stop, recent)

    private var chrome: some View {
        VStack {
            HStack {
                statusBadge
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Color.textCoolDim)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)

            Spacer()

            if showKeyboard { keyboardBar }
            bottomDock
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(config.isConfigured ? Theme.Color.green : Theme.Color.red)
                .frame(width: 7, height: 7)
            Text(config.selectedModel.isEmpty ? "no model" : shortModel)
                .font(Theme.Font.sansCaption)
                .foregroundStyle(Theme.Color.textCoolDim)
        }
    }

    private var bottomDock: some View {
        ZStack {
            // History grabber (swipe up / tap).
            VStack(spacing: 6) {
                Capsule().fill(Theme.Color.textCoolFaint).frame(width: 38, height: 4)
                Text("Recent sessions")
                    .font(Theme.Font.sansCaption)
                    .foregroundStyle(Theme.Color.textCoolDim)
            }
            .contentShape(Rectangle())
            .onTapGesture { showRecent = true }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { if $0.translation.height < -20 { showRecent = true } }
            )

            HStack {
                if viewModel?.isStreaming == true {
                    iconButton("stop.fill", tint: Theme.Color.red) { viewModel?.stop() }
                } else {
                    Color.clear.frame(width: 38, height: 38)
                }
                Spacer()
                iconButton("keyboard", tint: Theme.Color.aura) {
                    showKeyboard.toggle()
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var keyboardBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Type to Hermes…", text: $keyboardDraft, axis: .vertical)
                .font(Theme.Font.sansBody)
                .foregroundStyle(Theme.Color.textCool)
                .tint(Theme.Color.aura)
                .lineLimit(1...4)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            Button {
                sendText(keyboardDraft)
                keyboardDraft = ""
                showKeyboard = false
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Color.canvas)
                    .frame(width: 40, height: 40)
                    .background(canSendText ? Theme.Color.aura : Theme.Color.border, in: Circle())
            }
            .disabled(!canSendText)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private func iconButton(_ system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12), in: Circle())
        }
    }

    // MARK: - State mapping

    private var orbState: OrbState {
        if !config.isConfigured { return .offline }
        if recorder.isRecording { return .listening }
        if viewModel?.isStreaming == true {
            return (latestAssistant?.text.isEmpty == false) ? .speaking : .thinking
        }
        return .idle
    }

    private var captionText: String {
        switch orbState {
        case .idle: return "Hold to speak"
        case .listening: return isLocked ? "Listening — tap to send" : "Listening…"
        case .thinking: return "Thinking…"
        case .speaking: return "Hermes"
        case .offline: return "Tap settings to connect"
        }
    }

    private var latestAssistant: ChatMessage? {
        conversation?.orderedMessages.last(where: { $0.role == .assistant })
    }

    private var canSendText: Bool {
        !keyboardDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shortModel: String {
        let id = config.selectedModel
        return id.count > 16 ? "…" + id.suffix(14) : id
    }

    // MARK: - Gesture (hold OR tap-lock)

    private var orbGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in if pressStartedAt == nil { handlePressDown() } }
            .onEnded { _ in handlePressUp() }
    }

    private func handlePressDown() {
        pressStartedAt = Date()
        if isLocked { return }          // a press while locked resolves on release (stop & send)
        startListening()
    }

    private func handlePressUp() {
        let held = Date().timeIntervalSince(pressStartedAt ?? Date())
        pressStartedAt = nil
        if isLocked {
            isLocked = false
            stopAndSend()
            return
        }
        if held < tapThreshold {
            isLocked = true             // quick tap → latch hands-free; keep recording
        } else {
            stopAndSend()               // hold-release → send
        }
    }

    // MARK: - Voice + send

    private func startListening() {
        guard !recorder.isRecording else { return }
        liveTranscript = ""
        Task {
            let granted = await VoiceRecorder.requestAuthorization()
            guard granted else { permissionDenied = true; isLocked = false; return }
            try? recorder.start()
        }
    }

    private func stopAndSend() {
        let final = recorder.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscript = ""
        guard !final.isEmpty else { return }
        sendText(final)
    }

    private func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ensureConversation()
        viewModel?.send(text: trimmed, images: [])
    }

    // MARK: - Session management

    private func ensureConversation() {
        if conversation == nil {
            let convo = Conversation(model: config.selectedModel)
            modelContext.insert(convo)
            try? modelContext.save()
            conversation = convo
        }
        if viewModel == nil, let convo = conversation {
            viewModel = ChatViewModel(conversation: convo,
                                      client: HermesClient(config: config),
                                      config: config,
                                      context: modelContext)
        }
    }

    private func startNewSession() {
        showRecent = false
        conversation = nil
        viewModel = nil
        ensureConversation()
    }

    private func select(_ convo: Conversation) {
        showRecent = false
        conversation = convo
        viewModel = ChatViewModel(conversation: convo,
                                  client: HermesClient(config: config),
                                  config: config,
                                  context: modelContext)
    }

    private func loadModels() async {
        let client = HermesClient(config: config)
        if let fetched = try? await client.listModels(), !fetched.isEmpty {
            models = fetched
            if config.selectedModel.isEmpty || !fetched.contains(where: { $0.id == config.selectedModel }) {
                config.selectedModel = fetched.first!.id
            }
        }
    }
}
```

- [ ] **Step 2: Route the app to the orb home**

In `Psychopomp/App/PsychopompApp.swift`, in `RootView.body`, replace `ConversationListView()` with `OrbHomeView()`:

```swift
        Group {
            if config.isConfigured || connected {
                OrbHomeView()
            } else {
                ConnectionView { connected = true }
            }
        }
```

- [ ] **Step 3: Build**

Run the build command. Expected: BUILD SUCCEEDED.
(Task 5 creates `RecentSessionsSheet`. If building Task 4 alone, temporarily comment out the `.sheet(isPresented: $showRecent) { … }` block, then restore it in Task 5. Otherwise implement Task 5 before building.)

- [ ] **Step 4: Commit**

```bash
git add Psychopomp/Features/Orb/OrbHomeView.swift Psychopomp/App/PsychopompApp.swift
git commit -m "feat(orb): add OrbHomeView with hold/tap-lock voice loop; route app to it"
```

---

### Task 5: RecentSessionsSheet (swipe-up history)

**Files:**
- Create: `Psychopomp/Features/Orb/RecentSessionsSheet.swift`

- [ ] **Step 1: Create `RecentSessionsSheet.swift`**

```swift
import SwiftUI
import SwiftData

/// The swipe-up history sheet. Lists past conversations; lets the user continue one
/// by voice (`onSelect`), open its full transcript (`onOpen`), start a new session
/// (`onNew`), or delete.
struct RecentSessionsSheet: View {
    let current: Conversation?
    let onSelect: (Conversation) -> Void
    let onOpen: (Conversation) -> Void
    let onNew: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    var body: some View {
        NavigationStack {
            List {
                Button(action: onNew) {
                    Label("New session", systemImage: "plus")
                        .font(Theme.Font.sansBody)
                        .foregroundStyle(Theme.Color.aura)
                }
                .listRowBackground(Theme.Color.surface)

                ForEach(conversations) { convo in
                    row(convo)
                        .listRowBackground(Theme.Color.surface)
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.Color.canvas)
            .navigationTitle("Recent sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Theme.Color.aura)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.Color.canvas)
    }

    private func row(_ convo: Conversation) -> some View {
        HStack {
            Button { onSelect(convo) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if convo.id == current?.id {
                            Circle().fill(Theme.Color.green).frame(width: 6, height: 6)
                        }
                        Text(convo.title)
                            .font(Theme.Font.sansBody)
                            .foregroundStyle(Theme.Color.textCool)
                            .lineLimit(1)
                    }
                    Text(convo.updatedAt, format: .relative(presentation: .named))
                        .font(Theme.Font.sansCaption)
                        .foregroundStyle(Theme.Color.textCoolFaint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button { onOpen(convo) } label: {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Theme.Color.textCoolDim)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(conversations[index]) }
        try? modelContext.save()
    }
}
```

- [ ] **Step 2: Restore the sheet in OrbHomeView (if commented out in Task 4)**

Ensure this block is present and uncommented in `OrbHomeView.body`:

```swift
            .sheet(isPresented: $showRecent) {
                RecentSessionsSheet(
                    current: conversation,
                    onSelect: { select($0) },
                    onOpen: { showRecent = false; path.append($0) },
                    onNew: { startNewSession() }
                )
            }
```

- [ ] **Step 3: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Psychopomp/Features/Orb/RecentSessionsSheet.swift Psychopomp/Features/Orb/OrbHomeView.swift
git commit -m "feat(orb): add Recent sessions swipe-up sheet"
```

---

### Task 6: Polish — permission hint, idle settle, and manual end-to-end check

**Files:**
- Modify: `Psychopomp/Features/Orb/OrbHomeView.swift`

- [ ] **Step 1: Surface a mic-permission hint**

In `OrbHomeView`, add a permission hint under the caption. In `caption`, append after the `if orbState == .idle { … }` block (inside the `VStack`):

```swift
            if permissionDenied {
                Text("Microphone access is off — enable it in Settings, or use the keyboard.")
                    .font(Theme.Font.sansCaption)
                    .foregroundStyle(Theme.Color.red)
                    .multilineTextAlignment(.center)
            }
```

- [ ] **Step 2: Clear the permission hint when typing opens**

In the `keyboard` `iconButton` action, set the flag off:

```swift
                iconButton("keyboard", tint: Theme.Color.aura) {
                    permissionDenied = false
                    showKeyboard.toggle()
                }
```

- [ ] **Step 3: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual end-to-end verification (against a running Hermes agent)**

Run on the iPhone 16 simulator (or device). Confirm:
- App opens to the orb (idle, breathing) when configured; offline orb + "Tap settings to connect" when not.
- Hold the orb → ripples + "Listening…"; release → "Thinking…" → reply text streams under the orb as it pulses; tool chips appear for tool steps.
- Quick tap → latches to "Listening — tap to send"; tap again sends.
- Keyboard button → type → send runs the same pipeline.
- Swipe up / tap the grabber → Recent sessions; tap a row continues it by voice; the transcript icon opens the full `ChatView`; "New session" resets the orb.
- Stop button appears mid-run and stops the stream.
- Deny mic permission once → red hint appears and keyboard still works.

- [ ] **Step 5: Commit**

```bash
git add Psychopomp/Features/Orb/OrbHomeView.swift
git commit -m "feat(orb): permission hint and polish"
```

---

## Notes on retained / superseded code

- `ConversationListView.swift` is **superseded** by `OrbHomeView` + `RecentSessionsSheet` and is no longer referenced after Task 4. Leave it in place for now (harmless, file-synced build); a follow-up cleanup commit can delete it once the orb home is confirmed in the user's hands.
- `HermesConfig.pendingVoiceTranscript` was only used by the old list→chat hop and the old `ChatView.task` consumer. The orb home sends directly, so it's unused by the new path; `ChatView` still reads it harmlessly. Leave as-is; optional cleanup later.
- `Composer.swift` / `ChatView.swift` remain the **full transcript** experience, reached by expanding a reply or via the Recent sheet's transcript icon.
