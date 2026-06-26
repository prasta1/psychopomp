import SwiftUI

/// First-run onboarding: enter the Hermes API server URL + key and test the
/// connection before continuing.
struct ConnectionView: View {
    @Environment(HermesConfig.self) private var config
    var onConnected: () -> Void

    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var state: TestState = .idle

    private enum TestState: Equatable {
        case idle, testing, success(String), failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    SectionLabel("Server URL")
                    TerminalField(placeholder: "http://127.0.0.1:8642", text: $baseURL, keyboard: .URL)
                    Text("The address of your hermes-agent API server.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textDim)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    SectionLabel("API key (optional)")
                    TerminalField(placeholder: "API_SERVER_KEY", text: $apiKey, isSecure: true)
                    Text("Optional. Leave blank for LM Studio or unauthenticated servers. Stored securely in the iOS Keychain.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textDim)
                }

                statusView

                VStack(spacing: Theme.Spacing.md) {
                    TerminalButton(title: "Test connection", systemImage: "bolt",
                                   kind: .secondary, isLoading: state == .testing) {
                        Task { await test() }
                    }
                    TerminalButton(title: "Connect", systemImage: "arrow.right") {
                        persist()
                        onConnected()
                    }
                    .disabled(!canConnect)
                    .opacity(canConnect ? 1 : 0.5)
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .screenBackground()
        .onAppear {
            baseURL = config.baseURLString
            apiKey = config.apiKey
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("psychopomp")
                .font(Theme.Font.display)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("Connect to your Hermes agent.")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.top, Theme.Spacing.xxl)
    }

    @ViewBuilder
    private var statusView: some View {
        switch state {
        case .idle, .testing:
            EmptyView()
        case .success(let message):
            Label(message, systemImage: "checkmark.circle")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.green)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.red)
        }
    }

    private var canConnect: Bool {
        config.normalizedFrom(baseURL) != nil
    }

    private func persist() {
        config.baseURLString = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        config.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func test() async {
        persist()
        state = .testing
        let client = HermesClient(config: config)
        do {
            _ = try await client.health()
            let models = try await client.listModels()
            if models.isEmpty {
                state = .success("Connected. No models reported yet.")
            } else {
                if config.selectedModel.isEmpty { config.selectedModel = models.first!.id }
                state = .success("Connected · \(models.count) model(s) available")
            }
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}

extension HermesConfig {
    /// Validate an arbitrary string the way `normalizedBaseURL` validates the stored one.
    func normalizedFrom(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        guard let url = URL(string: stripped), url.scheme != nil, url.host != nil else { return nil }
        return url
    }
}
