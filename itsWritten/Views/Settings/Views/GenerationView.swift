//
//  GenerationView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 24/05/2026.
//

import SwiftUI

struct GenerationView: View {
    @Binding var configuration: ModelConfiguration
    @Binding var responseType: ModelResponseType

    var body: some View {
        Form {
            SamplingSection(configuration: $configuration)
            ResponseSection(configuration: $configuration, responseType: $responseType)
        }
        .formStyle(.grouped)
        .navigationTitle("Generation")
    }
}
