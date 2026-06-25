import Foundation
import SwiftUI

/// Holds connection settings. The base URL and selected model are non-secret and
/// persist in UserDefaults; the API key lives in the Keychain.
@Observable
final class HermesConfig {
    var baseURLString: String {
        didSet { UserDefaults.standard.set(baseURLString, forKey: Keys.baseURL) }
    }

    var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: Keys.model) }
    }

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
        self.selectedModel = UserDefaults.standard.string(forKey: Keys.model) ?? ""
        self.apiKey = Keychain.read() ?? ""
    }

    /// Whether enough is configured to attempt a connection.
    var isConfigured: Bool {
        normalizedBaseURL != nil && !apiKey.isEmpty
    }

    /// Trim trailing slashes and validate.
    var normalizedBaseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        guard let url = URL(string: stripped), url.scheme != nil, url.host != nil else { return nil }
        return url
    }

    private enum Keys {
        static let baseURL = "hermes.baseURL"
        static let model = "hermes.model"
    }
}
