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
