//
//  HomeView.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import SwiftUI

public typealias ActionVoid = () -> Void

struct HomeView: View {
    @Environment(HomeViewModel.self) var viewModel

    @FocusState private var isFocused: Bool

    @State private var text: String  = ""
    @State private var showTimeIsUpAlert: Bool = false
    @State private var showInputEmptyAlert: Bool = false
    @State private var showLowCharacterCountAlert: Bool = false
    @State private var showWhyAI: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                textfieldView

                if viewModel.timerActive || viewModel.timerPaused {
                    CountdownView(showTimeIsUpAlert: $showTimeIsUpAlert)
                }
            }
            .overlay {
                if viewModel.isResponding {
                    Image(systemName: "brain")
                        .symbolRenderingMode(.multicolor)
                        .symbolColorRenderingMode(.gradient)
                        .padding()
                        .background(.ultraThinMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassEffectContainer {
                        whyAIButtonView
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
            .sheet(isPresented: Binding(get: { viewModel.showAIGeneratedAnswer }, set: { viewModel.showAIGeneratedAnswer = $0 })) {
                AIGeneratedAnswerView(answer: viewModel.aiAnswer)
                    .background(.ultraThinMaterial)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .transition(.opacity)
            }
            .onAppear {
                viewModel.setRandomPlaceholderText()
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
            .alert(isPresented: Binding(get: { viewModel.showAIGenerationAlert }, set: { viewModel.showAIGenerationAlert = $0 })) {
                Alert(
                    title: Text("Response Error"),
                    message: Text(viewModel.errorMessage ?? "Try again later."),
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
            .foregroundStyle(viewModel.isResponding ? .secondary : .primary)
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
            .disabled(viewModel.isResponding)
    }

    var whyAIButtonView: some View {
        Button(action: {
            showWhyAI = true
        }) {
            Label("Why AI?", systemImage: "sparkles")
                .symbolRenderingMode(.multicolor)
        }
    }
}

// MARK: FooterView
extension HomeView {
    var footerView: some View {
        HStack {
            SendButtonView(
                isResponding: viewModel.isResponding,
                isInputEmpty: text.isEmpty,
                sendAction: {
                    handleSendTapped()
                }
            )
            .disabled(viewModel.isResponding)
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
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        isFocused = false
        Task { await viewModel.send(text: input) }
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
}
