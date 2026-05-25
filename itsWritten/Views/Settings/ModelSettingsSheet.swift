//
//  ModelSettingsSheet.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

struct ModelSettingsSheet: View {
    @Binding var configuration: ModelConfiguration
    @Binding var responseType: ModelResponseType
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section {
                NavigationLink("Provider") {
                    ProviderView()
                }
                NavigationLink("Instructions") {
                    InstructionSection(configuration: $configuration)
                        .navigationTitle("Instructions")
                        .navigationBarTitleDisplayMode(.inline)
                }
                NavigationLink("Generation") {
                    GenerationView(configuration: $configuration, responseType: $responseType)
                }
            } footer: {
                Text("Changing these settings may result in unexpected, inaccurate, or lower quality responses. Only modify them if you understand the effect each value has on the model's behaviour.")
            }

            AppInfoSection()

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    showResetConfirmation = true
                }
            } footer: {
                Text("Restores all model instructions and generation settings to their original values.")
            }
        }
        .navigationTitle("Settings")
        .formStyle(.grouped)
        .alert("Reset Model Settings", isPresented: $showResetConfirmation) {
            Button("Reset to Defaults", role: .destructive) {
                configuration = ModelConfiguration()
                responseType = .standard
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all model instructions and generation settings to their original values.")
        }
    }
}

#Preview {
    NavigationStack {
        ModelSettingsSheet(
            configuration: .constant(ModelConfiguration()),
            responseType: .constant(.streaming)
        )
    }
}
