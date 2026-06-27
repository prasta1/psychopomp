import SwiftUI
import UIKit

/// Edit the connection, re-run the health check, change the default model.
/// Styled to match the ethereal orb home (indigo wash, cool text, aura accents).
struct SettingsView: View {
    @Environment(HermesConfig.self) private var config
    @Environment(\.dismiss) private var dismiss
    @Bindable private var theme = ThemeManager.shared

    @State private var host = ""
    @State private var port = ""
    @State private var apiKey = ""
    @State private var models: [HermesModelInfo] = []
    @State private var status: String?
    @State private var statusOK = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                group("Appearance") {
                    Picker("Theme", selection: $theme.selected) {
                        ForEach(ThemeID.allCases) { id in
                            Text(id.displayName).tag(id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Color.aura)
                    .padding(Theme.Spacing.md)
                    .background(Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(Theme.Color.aura.opacity(0.35), lineWidth: 1)
                    )
                }

                group("Endpoint") {
                    Picker("Provider", selection: endpointBinding) {
                        ForEach(EndpointType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Color.aura)
                    .padding(Theme.Spacing.md)
                    .background(Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(Theme.Color.aura.opacity(0.35), lineWidth: 1)
                    )

                    if config.endpointType == .appleIntelligence {
                        appleIntelligenceSection
                    } else {
                        serverFieldsSection
                    }
                }

                if let status {
                    Label(status, systemImage: statusOK ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(Theme.Font.sansCaption)
                        .foregroundStyle(statusOK ? Theme.Color.green : Theme.Color.red)
                }

                VStack(spacing: Theme.Spacing.md) {
                    if config.endpointType.isServerBased {
                        secondaryButton("Test connection", system: "bolt") {
                            Task { await testConnection() }
                        }
                    }
                    if config.endpointType.isServerBased {
                        secondaryButton("Reload models", system: "arrow.clockwise") {
                            Task { await reloadModels() }
                        }
                    }
                    primaryButton("Save", system: "checkmark") {
                        persist(); dismiss()
                    }
                }

                aboutFooter
            }
            .padding(Theme.Spacing.xl)
        }
        .orbBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Color.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { persist(); dismiss() }.tint(Theme.Color.aura)
            }
        }
        .onAppear {
            let parsed = Self.parseURL(config.baseURLString)
            host = parsed.host
            port = parsed.port
            apiKey = config.apiKey
            if host.isEmpty && port.isEmpty {
                host = config.endpointType.defaultHost
                port = config.endpointType.defaultPort
            }
        }
        .task {
            if config.endpointType.isServerBased { await reloadModels() }
        }
    }

    // MARK: - Server fields (shown for LM Studio, Ollama, Tailscale)

    @ViewBuilder
    private var serverFieldsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            group("Server") {
                HStack(spacing: Theme.Spacing.sm) {
                    field("Host", text: $host, keyboard: .default)
                    field("Port", text: $port, keyboard: .numberPad)
                }
            }

            if config.endpointType.showsAPIKey {
                group("API key") {
                    field("API_SERVER_KEY (not required)", text: $apiKey, secure: true)
                }
            }

            group("Model") {
                if models.isEmpty {
                    Text("Tap \"Reload models\" to fetch available models")
                        .font(Theme.Font.sansBody)
                        .foregroundStyle(Theme.Color.textCoolFaint)
                } else {
                    Picker("Model", selection: modelSelection) {
                        ForEach(models) { Text($0.id).tag($0.id) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Color.aura)
                }
            }
        }
    }

    // MARK: - Apple Intelligence

    @ViewBuilder
    private var appleIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if config.isAppleIntelligenceActive {
                Label("Apple Intelligence is ready", systemImage: "checkmark.circle")
                    .font(Theme.Font.sansBody)
                    .foregroundStyle(Theme.Color.green)
            } else if config.useAppleIntelligence && !config.isAppleIntelligenceActive {
                Label("Not available on this device or not enabled in Settings.",
                      systemImage: "exclamationmark.triangle")
                    .font(Theme.Font.sansCaption)
                    .foregroundStyle(Theme.Color.red)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.Color.aura.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Ethereal building blocks

    @ViewBuilder
    private func group<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(label.uppercased())
                .font(Theme.Font.sansCaption)
                .foregroundStyle(Theme.Color.textCoolFaint)
                .tracking(1.2)
            content()
        }
    }

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>, secure: Bool = false,
                       keyboard: UIKeyboardType = .default) -> some View {
        Group {
            if secure { SecureField(placeholder, text: text) }
            else { TextField(placeholder, text: text) }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(keyboard)
        .font(Theme.Font.sansBody)
        .foregroundStyle(Theme.Color.textCool)
        .tint(Theme.Color.aura)
        .padding(Theme.Spacing.md)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.Color.textCoolFaint.opacity(0.5), lineWidth: 1)
        )
    }

    private func primaryButton(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            buttonLabel(title, system: system)
                .foregroundStyle(Theme.Color.canvas)
                .background(Theme.Color.aura,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            buttonLabel(title, system: system)
                .foregroundStyle(Theme.Color.textCool)
                .background(Color.white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.Color.aura.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func buttonLabel(_ title: String, system: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: system)
            Text(title)
        }
        .font(Theme.Font.sansBody.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var aboutFooter: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Rectangle().fill(Theme.Color.textCoolFaint.opacity(0.3)).frame(height: 1)
            Text("psychopomp · Hermes agent companion")
                .font(Theme.Font.sansCaption)
                .foregroundStyle(Theme.Color.textCoolFaint)
            Text("Sessions and history are stored on this device.")
                .font(Theme.Font.sansCaption)
                .foregroundStyle(Theme.Color.textCoolFaint)
        }
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Bindings

    private var endpointBinding: Binding<EndpointType> {
        Binding(
            get: { config.endpointType },
            set: { newType in
                config.endpointType = newType
                config.useAppleIntelligence = (newType == .appleIntelligence)
                host = newType.defaultHost
                port = newType.defaultPort
                models = []
                status = nil
                // Persist the new endpoint and auto-fetch models
                config.baseURLString = newType.defaultHost.isEmpty
                    ? ""
                    : "\(newType.defaultHost):\(newType.defaultPort)"
                if newType.isServerBased {
                    Task { await reloadModels() }
                }
            }
        )
    }

    private var modelSelection: Binding<String> {
        Binding(get: { config.selectedModel }, set: { config.selectedModel = $0 })
    }

    // MARK: - Actions

    private func persist() {
        let h = host.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
        let p = port.trimmingCharacters(in: .whitespacesAndNewlines)
        config.baseURLString = p.isEmpty ? h : "\(h):\(p)"
        config.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse a base URL string into host and port components.
    private static func parseURL(_ url: String) -> (host: String, port: String) {
        let trimmed = url.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
        if let colonRange = trimmed.range(of: ":", options: .backwards) {
            let host = String(trimmed[..<colonRange.lowerBound])
            let port = String(trimmed[colonRange.upperBound...])
            return (host, port)
        }
        return (trimmed, "")
    }

    private func testConnection() async {
        persist()
        status = nil
        let client = HermesClient(config: config)
        do {
            let ok = try await client.health()
            if ok {
                statusOK = true
                status = "Connected"
                await reloadModels()
            } else {
                statusOK = false
                status = "Server responded but health check failed"
            }
        } catch {
            statusOK = false
            status = error.localizedDescription
        }
    }

    private func reloadModels() async {
        persist()
        status = nil
        let client = HermesClient(config: config)
        do {
            let fetched = try await client.listModels()
            models = fetched
            if config.selectedModel.isEmpty, let first = fetched.first {
                config.selectedModel = first.id
            }
            statusOK = true
            status = fetched.isEmpty
                ? "Connected · no models reported"
                : "Connected · \(fetched.count) model(s)"
        } catch {
            statusOK = false
            status = error.localizedDescription
        }
    }
}
