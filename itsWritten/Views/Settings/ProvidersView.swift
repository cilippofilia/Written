//
//  ProvidersView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 24/05/2026.
//

import FoundationModels
import SwiftUI

enum AIProvider: String, CaseIterable, Identifiable {
    case appleIntelligence = "Apple Intelligence"
    case anthropic = "Anthropic"
    case openAI = "OpenAI"

    var id: Self { self }

    var isLocal: Bool { self == .appleIntelligence }

    var badge: String { isLocal ? "On Device" : "Cloud" }

    var systemImage: String { isLocal ? "cpu" : "cloud" }
}

struct ProvidersView: View {
    @State private var selectedProvider: AIProvider = .appleIntelligence
    @State private var pendingProvider: AIProvider?
    @State private var showProviderWarning = false
    @State private var isConfirmingSwitch = false

    var model = AppLanguageModel.model
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Label {
                            HStack {
                                Text(provider.rawValue)
                                Spacer()
                                Text(provider.badge)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        } icon: {
                            Image(systemName: provider.systemImage)
                        }
                        .tag(provider)
                    }
                }
            } footer: {
                Text("Apple Intelligence runs entirely on your device, keeping your writing private and available even without an internet connection.")
            }

            if selectedProvider == .appleIntelligence {
                let currentLanguage = Locale.current.language
                let isSupported = model.supportedLanguages.contains(currentLanguage)

                Section {
                    Button {
                        if let settingsURL = URL(string: "app-settings:") {
                            openURL(settingsURL)
                        }
                    } label: {
                        LabeledContent("Current Language") {
                            Text(displayName(for: currentLanguage))
                        }
                    }
                    .buttonStyle(.plain)

                    if isSupported {
                        Label("Current language is supported", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Current language is not supported", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Language Support")
                }

                Section("Supported Languages") {
                    ForEach(
                        Array(model.supportedLanguages).sorted { displayName(for: $0) < displayName(for: $1) },
                        id: \.self
                    ) { language in
                        Text(displayName(for: language))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Providers")
        .onChange(of: selectedProvider) { old, new in
            guard !isConfirmingSwitch else {
                isConfirmingSwitch = false
                return
            }
            if new != .appleIntelligence {
                pendingProvider = new
                selectedProvider = old
                showProviderWarning = true
            }
        }
        .alert("Switch Provider?", isPresented: $showProviderWarning) {
            Button("Continue", role: .destructive) {
                if let pending = pendingProvider {
                    isConfirmingSwitch = true
                    selectedProvider = pending
                }
            }
            Button("Cancel", role: .cancel) {
                pendingProvider = nil
            }
        } message: {
            Text("itsWritten is designed around Apple Intelligence, which keeps your writing private and fully on-device. Switching to a cloud provider means your text will be processed on external servers.")
        }
    }

    func displayName(for language: Locale.Language) -> String {
        let scriptsToShow: Set<Locale.Script> = [.hanSimplified, .hanTraditional]
        let scriptToUse = language.script.flatMap { scriptsToShow.contains($0) ? $0 : nil }

        let components = Locale.Components(
            languageCode: language.languageCode,
            script: scriptToUse,
            languageRegion: language.region
        )
        let locale = Locale(components: components)

        if let name = Locale.current.localizedString(forIdentifier: locale.identifier) {
            return name
        }

        if let code = language.languageCode?.identifier {
            return Locale.current.localizedString(forLanguageCode: code) ?? code
        }

        return "Unknown"
    }
}
