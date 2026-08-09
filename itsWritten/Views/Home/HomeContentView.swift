//
//  HomeContentView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import FoundationModels
import SwiftUI

struct HomeContentView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel

    @FocusState private var isFocused: Bool
    @State private var text = ""
    @State private var activeAlert: AlertType?
    @State private var presentedSheet: SheetType?
    @State private var showOverlayView = false

    @Binding var shouldSend: Bool

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType
    let session: LanguageModelSession

    var body: some View {
        VStack {
            HomeTextEditor(
                text: $text,
                isFocused: $isFocused,
                placeholderText: viewModel.placeholderText,
                isResponding: session.isResponding
            )
            #if !DEBUG
            .hideSensitiveData()
            #endif
            if countDownViewModel.timerActive || countDownViewModel.timerPaused {
                CountdownView()
            }
        }
        .overlay {
            if showOverlayView {
                RespondingIndicator()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                // Hidden while composing: keeps the ad out of the way of the keyboard, and
                // avoids reasoning about how an ad's own internal animations interact with
                // the keyboard-driven layout of this safeAreaInset.
                if isFocused == false {
                    CrossPromoBannerView()
                }

                HomeFooterView(
                    text: text,
                    isResponding: session.isResponding,
                    sendAction: {
                        shouldSend = true
                    }
                )
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            sheet.view
        }
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
        .task(id: shouldSend) {
            guard shouldSend else { return }
            await performSend()
            shouldSend = false
        }
        .onChange(of: countDownViewModel.timerExpired) { _, expired in
            if expired {
                activeAlert = .timeUp
            }
        }
    }
}

// MARK: - Send Logic
extension HomeContentView {
    @MainActor
    private func performSend() async {
        showOverlayView = true
        defer { showOverlayView = false }

        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            showOverlayView = false
            return
        }

        isFocused = false
        activeAlert = nil

        do {
            let title = try await generateTitle(from: prompt)
            presentedSheet = .chat(
                title: title,
                seedPrompt: prompt,
                session: session,
                config: $config,
                responseType: $responseType,
                threadId: nil,
                initialMessages: []
            )
            text = ""
        } catch let error as LanguageModelSession.GenerationError {
            activeAlert = .aiGenerationAlert(for: error)
        } catch {
            activeAlert = .aiGeneration(
                title: "Response Error",
                message: error.localizedDescription
            )
        }
    }

    @MainActor
    private func generateTitle(from input: String) async throws -> String {
        let instructions = """
        Summarize the prompt into a short title of 5 to 8 words.
        DO NOT use tools, lists, markdown, numbering, or quotes.
        Return only the title text.
        """
        let titleSession = AppLanguageModel.sessionWithoutTools(instructions: instructions)
        var title = ""
        for try await partial in titleSession.streamResponse(to: input) {
            title = partial.content
        }

        let normalized = title
            .replacing("\n", with: " ")
            .replacing("#", with: "")
            .replacing("-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let words = normalized.split(whereSeparator: \.isWhitespace)
        let clipped = words.prefix(8).joined(separator: " ")
        let finalTitle = clipped.isEmpty ? "New Conversation" : clipped
        return finalTitle
    }
}

#Preview {
    HomeContentView(
        shouldSend: .constant(false),
        config: .constant(ModelConfiguration()),
        responseType: .constant(.standard),
        session: AppLanguageModel.session()
    )
    .environment(HomeViewModel())
    .environment(CountdownViewModel())
    .environment(RemoveAdsStore())
}
