//
//  HomeContentView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import FoundationModels
import SwiftUI

struct HomeContentView: View {
    @Environment(ConversationViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel

    @FocusState private var isFocused: Bool
    @State private var text = ""
    @State private var activeAlert: AlertType?
    @State private var isSending = false

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType

    var body: some View {
        Group {
            switch viewModel.mode {
            case .composing:
                ComposingView(text: $text, isFocused: $isFocused, sendAction: sendButtonTapped)
            case .chatting:
                ChatConversationView(config: $config, responseType: $responseType)
            }
        }
        .animation(.default, value: viewModel.mode)
        .alert(activeAlert?.title ?? "", isPresented: .init(
            get: { activeAlert != nil },
            set: { if !$0 { activeAlert = nil } }
        )) {
            Button(activeAlert?.buttonText ?? "OK") {
                activeAlert = nil
            }
        } message: {
            Text(activeAlert?.message ?? "")
        }
        .onChange(of: countDownViewModel.timerExpired) { _, expired in
            if expired {
                activeAlert = .timeUp
            }
        }
    }

    private func sendButtonTapped() {
        Task { await performSend() }
    }

    @MainActor
    private func performSend() async {
        guard isSending == false else { return }
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }

        isSending = true
        defer { isSending = false }

        isFocused = false
        activeAlert = nil
        text = ""

        viewModel.startConversation(with: prompt, config: config, responseType: responseType)
        await viewModel.generateAndSetTitle(from: prompt)
    }
}

#Preview {
    HomeContentView(
        config: .constant(ModelConfiguration()),
        responseType: .constant(.standard)
    )
    .environment(HomeViewModel())
    .environment(CountdownViewModel())
    .environment(ConversationViewModel())
}
