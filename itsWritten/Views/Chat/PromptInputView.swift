//
//  PromptInputView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

/// A reusable input field for entering prompts with a send button.
///
/// This view provides a text field with automatic vertical expansion and a circular
/// send button that becomes disabled when the input is empty or the view is disabled.
struct PromptInputView: View {
    @Binding var text: String

    let placeholder: String
    let isDisabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .onSubmit(onSubmit)

            Button("Send", systemImage: "arrow.up.circle.fill", action: onSubmit)
                .imageScale(.large)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .blue.gradient)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .font(.title)
                .disabled(text.isReallyEmpty || isDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

#if DEBUG
private struct PromptInputPreviewWrapper: View {
    @State private var text = "Txt"

    let colorScheme: ColorScheme?

    var body: some View {
        PromptInputView(
            text: $text,
            placeholder: "Placeholder",
            isDisabled: false,
            onSubmit: { }
        )
        .preferredColorScheme(colorScheme)
    }
}

#Preview("Dark") {
    PromptInputPreviewWrapper(colorScheme: .dark)
}

#Preview("Light") {
    PromptInputPreviewWrapper(colorScheme: .light)
}
#endif
