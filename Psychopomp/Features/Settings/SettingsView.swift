import SwiftUI
import UIKit

/// Edit the connection, re-run the health check, change the default model.
/// Styled to match the ethereal orb home (indigo wash, cool text, aura accents).
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
                aiProviderSection
                group("Server URL") {
                    field("http://127.0.0.1:8642", text: $baseURL, keyboard: .URL)
                }
                group("API key") {
                    field("API_SERVER_KEY", text: $apiKey, secure: true)
                }
                if !config.useAppleIntelligence {
                    group("Default model") {
                        if models.isEmpty {
                            Text(config.selectedModel.isEmpty ? "Reload to fetch models" : config.selectedModel)
                                .font(Theme.Font.sansBody)
                                .foregroundStyle(Theme.Color.textCoolDim)
                        } else {
                            Picker("Model", selection: modelSelection) {
                                ForEach(models) { Text($0.id).tag($0.id) }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.Color.aura)
                        }
                    }
                }

                if let status {
                    Label(status, systemImage: statusOK ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(Theme.Font.sansCaption)
                        .foregroundStyle(statusOK ? Theme.Color.green : Theme.Color.red)
                }

                VStack(spacing: Theme.Spacing.md) {
                    if !config.useAppleIntelligence {
                        secondaryButton("Test & reload models", system: "arrow.clockwise") {
                            Task { await reload() }
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
            baseURL = config.baseURLString
            apiKey = config.apiKey
        }
        .task {
            if !config.useAppleIntelligence { await reload() }
        }
    }

    // MARK: - Apple Intelligence section

    @ViewBuilder
    private var aiProviderSection: some View {
        group("AI Provider") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Toggle(isOn: Binding(
                    get: { config.useAppleIntelligence },
                    set: { config.useAppleIntelligence = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Intelligence")
                            .font(Theme.Font.sansBody)
                            .foregroundStyle(Theme.Color.textCool)
                        Text("On-device model · no server required")
                            .font(Theme.Font.sansCaption)
                            .foregroundStyle(Theme.Color.textCoolFaint)
                    }
                }
                .tint(Theme.Color.aura)

                if config.useAppleIntelligence && config.appleIntelligenceClient == nil {
                    Label("Apple Intelligence is not available on this device or not enabled in Settings.",
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
