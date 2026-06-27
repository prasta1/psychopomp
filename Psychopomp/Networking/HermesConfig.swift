import Foundation
import SwiftUI

/// Which AI backend the user is connecting to.
enum EndpointType: String, CaseIterable, Identifiable {
    case hermes, lmStudio, ollama, custom, appleIntelligence

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hermes: return "Hermes"
        case .lmStudio: return "LM Studio"
        case .ollama: return "Ollama"
        case .custom: return "Custom"
        case .appleIntelligence: return "Apple Intelligence"
        }
    }

    var defaultPort: String {
        switch self {
        case .hermes: return "8642"
        case .lmStudio: return "1234"
        case .ollama: return "11434"
        case .custom: return "8642"
        case .appleIntelligence: return ""
        }
    }

    var defaultHost: String {
        switch self {
        case .hermes, .custom: return ""
        case .lmStudio, .ollama: return "127.0.0.1"
        case .appleIntelligence: return ""
        }
    }

    var showsAPIKey: Bool {
        switch self {
        case .hermes, .lmStudio, .ollama: return false
        case .custom: return true
        case .appleIntelligence: return false
        }
    }

    var isServerBased: Bool { self != .appleIntelligence }
}

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

    /// The user's chosen endpoint type. Persisted.
    var endpointType: EndpointType {
        didSet { UserDefaults.standard.set(endpointType.rawValue, forKey: Keys.endpointType) }
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

        // Restore endpoint type.
        let savedEndpoint = UserDefaults.standard.string(forKey: Keys.endpointType)
        self.endpointType = savedEndpoint.flatMap(EndpointType.init(rawValue:)) ?? .lmStudio

        // Determine Apple Intelligence availability and set up the client.
        var aiClient: AnyObject? = nil
        var useAI = false
        if #available(iOS 26.0, *) {
            let client = AppleIntelligenceClient()
            if client.isAvailable {
                aiClient = client
                let saved = UserDefaults.standard.object(forKey: Keys.useAppleIntelligence) as? Bool
                useAI = saved ?? true
            }
        }
        self.useAppleIntelligence = useAI
        self.appleIntelligenceClient = aiClient

        let savedModel = UserDefaults.standard.string(forKey: Keys.model)
        if let savedModel, !savedModel.isEmpty {
            self.selectedModel = savedModel
        } else if useAI {
            self.selectedModel = "Apple Intelligence"
        } else {
            self.selectedModel = ""
        }
    }

    /// Whether enough is configured to make a request.
    var isConfigured: Bool {
        if isAppleIntelligenceActive { return true }
        return normalizedBaseURL != nil
    }

    /// Apple Intelligence ready to use.
    var isAppleIntelligenceActive: Bool {
        useAppleIntelligence && appleIntelligenceClient != nil
    }

    /// Trim trailing slashes and validate.
    var normalizedBaseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        let withScheme = stripped.contains("://") ? stripped : "http://\(stripped)"
        guard let url = URL(string: withScheme), url.host != nil else { return nil }
        return url
    }

    private enum Keys {
        static let baseURL = "hermes.baseURL"
        static let model = "hermes.model"
        static let useAppleIntelligence = "hermes.useAppleIntelligence"
        static let endpointType = "hermes.endpointType"
    }
}
