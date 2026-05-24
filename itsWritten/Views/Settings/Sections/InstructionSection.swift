//
//  InstructionSection.swift
//  itsWritten
//
//  Created by Filippo Cilia on 28/02/2026.
//

import SwiftUI

struct InstructionSection: View {
    @Binding var configuration: ModelConfiguration
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $configuration.instructions)
            .contentMargins(16, for: .scrollContent)
            .focused($isFocused)
            .scrollIndicators(.hidden)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isFocused = false
                    }
                }
            }
    }
}
