//
//  ResponseSection.swift
//  itsWritten
//
//  Created by Filippo Cilia on 28/02/2026.
//

import SwiftUI

struct ResponseSection: View {
    @Binding var configuration: ModelConfiguration
    @Binding var responseType: ModelResponseType

    var body: some View {
        Section {
            LabeledContent("Temperature: \(configuration.temperature, format: .number.precision(.fractionLength(2)))") {
                Slider(value: $configuration.temperature, in: 0...1)
            }

            Picker("Speed", selection: $responseType) {
                ForEach(ModelResponseType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Response")
                .padding(.top)
        } footer: {
            Text("""
            Temperature: Controls response randomness where 0 is random, 1 is deterministic.
            Standard: Generates the full response before displaying it.
            Streaming: Displays the response word by word as it is generated.
            Human: Displays the response character by character, mimicking natural typing.
            """)
        }
    }
}
