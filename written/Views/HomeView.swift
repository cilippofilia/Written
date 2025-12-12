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
        }
    }
}


// MARK: Subviews
extension HomeView {
    var textfieldView: some View {
        TextEditor(text: $text)
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
            .scrollContentBackground(.hidden)
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
            // center button
            SendButtonView()

            // right menu
            TimerButtonView()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
}
