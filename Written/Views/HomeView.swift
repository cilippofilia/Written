//
//  HomeView.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import SwiftUI

public typealias ActionVoid = () -> Void

struct HomeView: View {
    @AppStorage("selectedPromptID") private var selectedModelID: String = ""

    @Environment(HomeViewModel.self) var viewModel
    @Environment(CountdownViewModel.self) var countDownViewModel
    @FocusState private var isFocused: Bool

    @State private var text: String  = ""
    @State private var aiAnswer: String  = ""

    @State private var activeAlert: AlertType?
    @State private var errorTitle: String? = nil
    @State private var errorMessage: String? = nil

    @State private var showAIGeneratedAnswer: Bool = false
    @State private var showWhyAISheet: Bool = false
    @State private var showOverlayView: Bool = false

    @State private var shouldSend: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                textfieldView

                if countDownViewModel.timerActive || countDownViewModel.timerPaused {
                    CountdownView()
                }
            }
            .overlay {
                if showOverlayView {
                    RespondingIndicator()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassEffectContainer {
                        MenuButtonView(
                            selectedModel: .init(
                                get: { viewModel.selectedAIModel },
                                set: { viewModel.updateSelection(to: $0) }
                            ),
                            aiModels: viewModel.aiModelList,
                            showWhyAISheet: $showWhyAISheet
                        )
                        .onChange(of: viewModel.selectedAIModel) { _, newModel in
                            selectedModelID = newModel.id
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                GlassEffectContainer {
                    footerView
                }
            }
            .sheet(isPresented: $showWhyAISheet) {
                WhyAIView(action: { showWhyAISheet = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAIGeneratedAnswer) {
                AIGeneratedAnswerView(answer: aiAnswer)
                    .background(.ultraThinMaterial)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .transition(.opacity)
                    .onAppear {
                        showOverlayView = false
                    }
                    .onDisappear {
                        viewModel.session = nil
                        text = ""
                    }
            }
            .onAppear {
                viewModel.prepareInitialState(storedModelID: selectedModelID)
            }
            .task(id: shouldSend) {
                guard shouldSend else { return }
                await performSend()
                shouldSend = false
            }
            .alert(activeAlert?.title ?? "", isPresented: Binding(
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
    }
}

// MARK: Subviews
extension HomeView {
    var textfieldView: some View {
        TextEditor(text: $text)
            .foregroundStyle((viewModel.session?.isResponding ?? false) ? .secondary : .primary)
            .padding(.horizontal, 8)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(viewModel.placeholderText)
                        .foregroundStyle(.secondary)
                        .padding(.leading)
                        .padding(.top, 8)
                        .opacity(isFocused ? 0.2 : 1)
                        .animation(.easeInOut, value: isFocused)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .focused($isFocused)
            .scrollBounceBehavior(.basedOnSize)
            .scrollContentBackground(.hidden)
            .disabled(viewModel.session?.isResponding ?? false)
    }
}

// MARK: FooterView
extension HomeView {
    var footerView: some View {
        HStack {
            SendButtonView(
                isResponding: viewModel.session?.isResponding ?? false,
                isInputEmpty: text.isEmpty,
                sendAction: {
                    handleSendTapped()
                }
            )
            .disabled(viewModel.session?.isResponding ?? false)
            .disabled(text.isEmpty)

            TimerButtonView()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Send logic helpers
extension HomeView {
    @MainActor
    private func handleSendTapped() {
        shouldSend = true
    }

    @MainActor
    private func performSend() async {
        showOverlayView = true

        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            showOverlayView = false
            return
        }

        isFocused = false
        resetAlerts()

        guard let session = viewModel.session else { return }

        do {
            let stream = session.streamResponse(to: input)
            for try await partial in stream {
                aiAnswer = partial.content
                withAnimation {
                    showAIGeneratedAnswer = true
                }
            }
        } catch let error as LanguageModelSession.GenerationError {
            handleGenerationError(error)
        } catch {
            if let error = error as? FoundationModels.LanguageModelSession.GenerationError {
                errorMessage = "Error: \(error.localizedDescription)"
            } else {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            activeAlert = .aiGeneration(
                title: errorTitle ?? "Response Error",
                message: errorMessage ?? "Try again later."
            )
        }
        showOverlayView = false
    }

    @MainActor
    private func resetAlerts() {
        errorMessage = nil
        activeAlert = nil
        showAIGeneratedAnswer = false
    }

    @MainActor
    private func handleGenerationError(_ error: LanguageModelSession.GenerationError) {
        switch error {
        case .guardrailViolation(let context):
            errorTitle = "Guardrail Violation"
            errorMessage = "\(context.debugDescription)"
        case .decodingFailure(let context):
            errorTitle = "Decoding Failure"
            errorMessage = "\(context.debugDescription)"
        case .rateLimited(let context):
            errorTitle = "Rate Limited"
            errorMessage = "\(context.debugDescription)"
        default:
            errorTitle = "Response Error"
            errorMessage = "\(error.localizedDescription)"
        }
        if let recoverySuggestion = error.recoverySuggestion {
            let base = errorMessage ?? ""
            errorMessage = base + "\n\n\(recoverySuggestion)" + "\(error.helpAnchor ?? "")"
        }
        activeAlert = .aiGeneration(
            title: errorTitle ?? "Response Error",
            message: errorMessage ?? "Try again later."
        )
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
        .environment(CountdownViewModel())
}
