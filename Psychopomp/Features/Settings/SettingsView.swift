import SwiftUI

/// Edit the connection, re-run the health check, change the default model.
struct SettingsView: View {
    @Environment(HermesConfig.self) private var config
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var models: [HermesModelInfo] = []
    @State private var status: String?
    @State private var statusOK = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                group("Server URL") {
                    TerminalField(placeholder: "http://127.0.0.1:8642", text: $baseURL, keyboard: .URL)
                }
                group("API key") {
                    TerminalField(placeholder: "API_SERVER_KEY", text: $apiKey, isSecure: true)
                }
                group("Default model") {
                    if models.isEmpty {
                        Text(config.selectedModel.isEmpty ? "Reload to fetch models" : config.selectedModel)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textSecondary)
                    } else {
                        Picker("Model", selection: modelSelection) {
                            ForEach(models) { Text($0.id).tag($0.id) }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.Color.accent)
                    }
                }

                if let status {
                    Label(status, systemImage: statusOK ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(Theme.Font.caption)
                        .foregroundStyle(statusOK ? Theme.Color.green : Theme.Color.red)
                }

                VStack(spacing: Theme.Spacing.md) {
                    TerminalButton(title: "Test & reload models", systemImage: "arrow.clockwise", kind: .secondary) {
                        Task { await reload() }
                    }
                    TerminalButton(title: "Save", systemImage: "checkmark") {
                        persist()
                        dismiss()
                    }
                }

                aboutFooter
            }
            .padding(Theme.Spacing.xl)
        }
        .screenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { persist(); dismiss() }.tint(Theme.Color.accent)
            }
        }
        .onAppear {
            baseURL = config.baseURLString
            apiKey = config.apiKey
        }
        .task { await reload() }
    }

    private func group<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionLabel(label)
            content()
        }
    }

    private var aboutFooter: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Hairline().opacity(0.5)
            Text("psychopomp · Hermes agent companion")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textDim)
            Text("Sessions and history are stored on this device.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textDim)
        }
        .padding(.top, Theme.Spacing.md)
    }

    private var modelSelection: Binding<String> {
        Binding(get: { config.selectedModel }, set: { config.selectedModel = $0 })
    }

    private func persist() {
        config.baseURLString = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        config.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func reload() async {
        persist()
        let client = HermesClient(config: config)
        do {
            let fetched = try await client.listModels()
            models = fetched
            if config.selectedModel.isEmpty, let first = fetched.first { config.selectedModel = first.id }
            statusOK = true
            status = fetched.isEmpty ? "Connected. No models reported." : "Connected · \(fetched.count) model(s)"
        } catch {
            statusOK = false
            status = error.localizedDescription
        }
    }
}
