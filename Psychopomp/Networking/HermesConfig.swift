import Foundation
import SwiftUI

/// Holds connection settings and AI provider selection.
/// Base URL and selected model are non-secret and persist in UserDefaults;
/// the API key lives in the Keychain.
@Observable
final class HermesConfig {
    var baseURLString: String {
        didSet { UserDefaults.standard.set(baseURLString, forKey: Keys.baseURL) }
    }

    var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: Keys.model) }
    }

    /// When true, the on-device Apple Intelligence model is used instead of the
    /// Hermes server. Persisted so the choice survives app restarts.
    var useAppleIntelligence: Bool {
        didSet {
            UserDefaults.standard.set(useAppleIntelligence, forKey: Keys.useAppleIntelligence)
            if useAppleIntelligence {
                if #available(iOS 26.0, *) {
                    let client = AppleIntelligenceClient()
                    if client.isAvailable {
                        appleIntelligenceClient = client
                        selectedModel = AppleIntelligenceClient.modelDisplayName
                        return
                    }
                }
                // Apple Intelligence unavailable — leave the flag set but clear the client.
                appleIntelligenceClient = nil
            } else {
                appleIntelligenceClient = nil
                if selectedModel == "Apple Intelligence" { selectedModel = "" }
            }
        }
    }

    /// Opaque runtime reference to `AppleIntelligenceClient` (stored as `AnyObject`
    /// to avoid `@available` annotations at every call site). Non-nil only when
    /// iOS 26+ with Apple Intelligence available and `useAppleIntelligence == true`.
    var appleIntelligenceClient: AnyObject?

    /// Backed by the Keychain.
    var apiKey: String {
        didSet {
            if apiKey.isEmpty { Keychain.delete() } else { Keychain.save(apiKey) }
        }
    }

    /// Transient: voice transcript captured via the PTT button on the list screen.
    /// Consumed once by the next ChatView that appears.
    var pendingVoiceTranscript: String = ""

    init() {
        self.baseURLString = UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
        self.apiKey = Keychain.read() ?? ""

        // Determine Apple Intelligence availability and set up the client.
        var aiClient: AnyObject? = nil
        var useAI = false
        if #available(iOS 26.0, *) {
            let client = AppleIntelligenceClient()
            if client.isAvailable {
                aiClient = client
                let saved = UserDefaults.standard.object(forKey: Keys.useAppleIntelligence) as? Bool
                useAI = saved ?? true   // Default: enabled when Apple Intelligence is present
            }
        }
        self.useAppleIntelligence = useAI
        self.appleIntelligenceClient = aiClient

        // Select a default model for display.
        let savedModel = UserDefaults.standard.string(forKey: Keys.model)
        if let savedModel, !savedModel.isEmpty {
            self.selectedModel = savedModel
        } else if useAI {
            self.selectedModel = "Apple Intelligence"
        } else {
            self.selectedModel = "nousresearch/hermes-4-70b"
        }
    }

    /// Whether enough is configured to make a request.
    var isConfigured: Bool {
        if useAppleIntelligence && appleIntelligenceClient != nil { return true }
        return normalizedBaseURL != nil
    }

    /// Host portion of the server URL (no scheme, no port).
    var host: String {
        get {
            let trimmed = baseURLString
                .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
            if let colonRange = trimmed.range(of: ":", options: .backwards) {
                // Could be host:port or [ipv6]:port — strip port
                let candidate = String(trimmed[..<colonRange.lowerBound])
                return candidate.hasPrefix("[") && candidate.hasSuffix("]")
                    ? String(candidate.dropFirst().dropLast())
                    : candidate
            }
            return trimmed
        }
        set {
            let portPart = port.isEmpty ? "" : ":\(port)"
            let cleaned = newValue
                .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
            baseURLString = "\(cleaned)\(portPart)"
        }
    }

    /// Port portion of the server URL. Defaults to "8642".
    var port: String {
        get {
            let trimmed = baseURLString
                .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
            // Find last colon that isn't inside brackets (IPv6)
            if let colonRange = trimmed.range(of: ":", options: .backwards) {
                let afterColon = trimmed[colonRange.upperBound...]
                if !afterColon.isEmpty { return String(afterColon) }
            }
            return ""
        }
        set {
            let hostPart = host
            let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty {
                baseURLString = hostPart
            } else {
                baseURLString = "\(hostPart):\(cleaned)"
            }
        }
    }

    /// Trim trailing slashes and validate.
    var normalizedBaseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        // If no scheme, prepend http:// so URL() can parse host + port
        let withScheme = stripped.contains("://") ? stripped : "http://\(stripped)"
        guard let url = URL(string: withScheme), url.host != nil else { return nil }
        return url
    }

    private enum Keys {
        static let baseURL = "hermes.baseURL"
        static let model = "hermes.model"
        static let useAppleIntelligence = "hermes.useAppleIntelligence"
    }
}
