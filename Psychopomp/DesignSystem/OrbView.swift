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

    @State private var swirling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let diameter: CGFloat = 160

    var body: some View {
        Group {
            if reduceMotion || state == .offline {
                // Hold still for Reduce Motion and when there's nothing to convey.
                layers
            } else {
                // PhaseAnimator drives a continuous breath whose speed re-times
                // whenever `state` changes (trigger), unlike a one-shot repeatForever.
                PhaseAnimator([false, true], trigger: state) { expanded in
                    layers.scaleEffect(breathScale(expanded))
                } animation: { _ in
                    .easeInOut(duration: breathDuration)
                }
            }
        }
        .onAppear { swirling = true }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    /// The static visual stack. Breath/scale is applied by the PhaseAnimator above;
    /// glow and color changes cross-fade on state transitions.
    private var layers: some View {
        ZStack {
            if state == .listening { ripples }
            coreBase
            if state == .thinking { swirlOverlay }
            highlight
        }
        .frame(width: 210, height: 210)
        .animation(.easeInOut(duration: 0.4), value: state)
    }

    // MARK: Layers

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

    /// Target scale for each breath phase (`expanded` = inhaled).
    private func breathScale(_ expanded: Bool) -> CGFloat {
        guard expanded else { return 1.0 }
        switch state {
        case .listening, .speaking: return 1.08
        case .thinking: return 1.04
        case .idle: return 1.05
        case .offline: return 1.0
        }
    }

    /// Per-state breath duration — faster when listening/replying, slow at rest.
    private var breathDuration: Double {
        switch state {
        case .idle: return 5.0
        case .listening: return 2.1
        case .thinking: return 3.4
        case .speaking: return 1.5
        case .offline: return 0
        }
    }

    private var rippleIntensity: Double { 0.5 + min(audioLevel, 1.0) * 0.5 }

    private var accessibilityLabel: String {
        switch state {
        case .idle: return "Orb. Idle. Talk to Me Heath."
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
