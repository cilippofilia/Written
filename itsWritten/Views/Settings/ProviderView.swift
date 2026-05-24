//
//  ProviderView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 24/05/2026.
//

import FoundationModels
import SwiftUI

struct ProviderView: View {
    var model = AppLanguageModel.model
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                Label("Apple Intelligence", systemImage: "apple.intelligence")
                    .symbolRenderingMode(.multicolor)
            } footer: {
                Text("Apple Intelligence runs entirely on your device, keeping your writing private and available even without an internet connection.")
            }

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
        .formStyle(.grouped)
        .navigationTitle("Provider")
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
