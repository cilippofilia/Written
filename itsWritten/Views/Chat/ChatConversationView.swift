//
//  ChatConversationView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 09/08/2026.
//

import SwiftUI

struct ChatConversationView: View {
    @Environment(ConversationViewModel.self) private var viewModel
    @Environment(HomeViewModel.self) private var homeViewModel

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType

    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(
                messages: viewModel.messages,
                isResponding: viewModel.isResponding
            )

            PromptInputView(
                text: $input,
                placeholder: homeViewModel.placeholderText,
                isDisabled: viewModel.isResponding,
                onSubmit: sendMessage
            )
        }
        #if !DEBUG
        .hideSensitiveData()
        #endif
        .navigationTitle(viewModel.title)
        .onChange(of: config.instructions) {
            viewModel.rebuildSession(config: config)
        }
    }

    private func sendMessage() {
        guard input.isReallyEmpty == false else { return }
        let prompt = input
        input = ""
        viewModel.sendMessage(prompt, config: config, responseType: responseType)
    }
}

#Preview {
    NavigationStack {
        ChatConversationView(
            config: .constant(ModelConfiguration()),
            responseType: .constant(.standard)
        )
    }
    .environment(ConversationViewModel())
    .environment(HomeViewModel())
}
