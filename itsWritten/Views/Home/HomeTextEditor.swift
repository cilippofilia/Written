//
//  HomeTextEditor.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import SwiftUI

struct HomeTextEditor: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    let placeholderText: String
    let isResponding: Bool

    var body: some View {
        TextEditor(text: $text)
            .foregroundStyle(isResponding ? .secondary : .primary)
            .padding(.horizontal, 8)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .padding(.leading)
                        .padding(.top, 8)
                        .opacity(isFocused ? 0.2 : 1)
                        .animation(.easeInOut, value: isFocused)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .focused($isFocused)
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .disabled(isResponding)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text: String = "TEST"
        @FocusState private var isFocused: Bool

        var body: some View {
            HomeTextEditor(
                text: $text,
                isFocused: $isFocused,
                placeholderText: "Placeholder text",
                isResponding: false
            )
        }
    }
    return PreviewWrapper()
}
