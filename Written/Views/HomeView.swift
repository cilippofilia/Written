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
    @AppStorage("selectedPromptID") private var selectedPromptID: String = ""

    @Environment(HomeViewModel.self) var viewModel

    @FocusState private var isFocused: Bool

    @State private var text: String  = ""
    @State private var aiAnswer: String  = ""
    @State private var errorTitle: String? = nil
    @State private var errorMessage: String? = nil

    @State private var showTimeIsUpAlert: Bool = false
    @State private var showAIGenerationAlert: Bool = false
    @State private var showInputEmptyAlert: Bool = false
    @State private var showAIGeneratedAnswer: Bool = false
    @State private var showLowCharacterCountAlert: Bool = false
    @State private var showWhyAI: Bool = false
    @State private var showSettings: Bool = false
    @State private var showOverlay: Bool = false

    @State private var shouldSend: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                textfieldView

                if viewModel.timerActive || viewModel.timerPaused {
                    CountdownView(showTimeIsUpAlert: $showTimeIsUpAlert)
                }
            }
            .overlay {
                if showOverlay {
                    RespondingIndicator()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassEffectContainer {
                        MenuButtonView(
                            selectedModel: .init(
                                get: { viewModel.selectedPrompt },
                                set: { viewModel.updateSelection(to: $0) }
                            ),
                            models: viewModel.promptOptions,
                            showWhyAISheet: $showWhyAI
                        )
                        .onChange(of: viewModel.selectedPrompt) { _, newPrompt in
                            selectedPromptID = newPrompt.id
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                GlassEffectContainer {
                    footerView
                }
            }
            .sheet(isPresented: $showWhyAI) {
                WhyAIView(action: { showWhyAI = false })
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
                        showOverlay = false
                    }
                    .onDisappear {
                        viewModel.session = nil
                        text = ""
                    }
            }
            .onAppear {
                viewModel.prepareInitialState(storedPromptID: selectedPromptID)
            }
            .task(id: shouldSend) {
                guard shouldSend else { return }
                await performSend()
                shouldSend = false
            }
            .alert(isPresented: $showTimeIsUpAlert) {
                Alert(
                    title: Text("Time is up!"),
                    message: Text("Feel free to finish up your thoughts and then press Send!"),
                    dismissButton: .default(Text("Got it!"))
                )
            }
            .alert(isPresented: $showInputEmptyAlert) {
                Alert(
                    title: Text("OOPS!"),
                    message: Text("Your input is empty.\nStart the timer, set it to the minimum and start typing away!"),
                    dismissButton: .default(Text("Dismiss"))
                )
            }
            .alert(isPresented: $showLowCharacterCountAlert) {
                Alert(
                    title: Text("OOPS!"),
                    message: Text("Your input is empty.\nStart the timer, set it to the minimum and start typing away!"),
                    dismissButton: .default(Text("Dismiss"))
                )
            }
            .alert(isPresented: $showAIGenerationAlert) {
                Alert(
                    title: Text("Response Error"),
                    message: Text(errorMessage ?? "Try again later."),
                    dismissButton: .default(Text("Got it!"))
                )
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
        showOverlay = true

        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        isFocused = false
        resetAlerts()

        guard let session = viewModel.session else { return }

        do {
            let stream = session.streamResponse(to: input)
            for try await partial in stream {
                aiAnswer = partial.content
                withAnimation {
                    showAIGeneratedAnswer = true
                    showAIGenerationAlert = false
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
            showAIGenerationAlert = true
        }
        showOverlay = false
    }

    @MainActor
    private func resetAlerts() {
        errorMessage = nil
        showAIGenerationAlert = false
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
        showAIGenerationAlert = true
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
}
