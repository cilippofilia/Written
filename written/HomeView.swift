//
//  HomeView.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import SwiftUI

public typealias ActionVoid = () -> Void

struct HomeView: View {
    @State private var timerActive: Bool = false
    @State private var timerPaused: Bool = false

    @State private var showTimeIsUpAlert: Bool = false
    @State private var showingChatMenu: Bool = false
    @State private var showSettings: Bool = false

    @State private var didCopyPrompt: Bool = false

    let timers: [Int] = [300, 600, 900, 1200, 1500, 1800]

    @StateObject var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                textfieldView

                if timerActive || timerPaused {
                    HStack {
                        Image(systemName: "timer")
                        Text(viewModel.formattedTimeLeft)
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .bold()
                }
            }
            .safeAreaInset(edge: .bottom) {
                footerView
            }
            .navigationDestination(
                isPresented: $showSettings,
                destination: {
                    SettingsView()
                        .background(meshBackground())
                }
            )
            .onAppear {
                viewModel.setRandomPlaceholderText()
            }
            .background {
                meshBackground()
            }
            .alert(isPresented: $showTimeIsUpAlert) {
                Alert(
                    title: Text("Time is up!"),
                    message: Text("Feel free to finish up your thoughts!"),
                    dismissButton: .default(Text("Got it!"))
                )
            }
        }
    }
}

// MARK: Methods
extension HomeView {
    func startTimer() {
        timerActive = true
        timerPaused = false
        viewModel.timer?.invalidate()
        viewModel.timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true,
            block: { _ in
                if viewModel.timeRemaining != 0 {
                    viewModel.timeRemaining -= 1
                } else {
                    stopTimer()
                    showTimeIsUpAlert = true
                }
            }
        )
    }

    func pauseTimer() {
        viewModel.timer?.invalidate()
        timerPaused = true
    }

    func stopTimer() {
        viewModel.timer?.invalidate()
        viewModel.timer = nil
        viewModel.timeRemaining = 0
        timerActive = false
        timerPaused = false
    }
}

// MARK: Subviews
extension HomeView {
    var timerButtonImage: Image {
        if !timerActive {
            Image(systemName: "timer")
        } else if timerPaused {
            Image(systemName: "play.circle")
        } else {
            Image(systemName: "pause.circle")
        }
    }

    var textfieldView: some View {
        TextField(
            "",
            text: $viewModel.text,
            axis: .vertical
        )
        .overlay(alignment: .leading) {
            if viewModel.text.isEmpty {
                Text(viewModel.placeholderText)
                    .foregroundStyle(.secondary)
                    .bold()
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    func popoverSendContent() -> some View {
        if viewModel.isUrlTooLong {
            promptTooLongContent()
        } else if viewModel.text.count < 350 {
            promptTooShortContent
        } else {
            aiModelsMenu()
        }
    }

    func copyPromptButtonView() -> some View {
        Button(action: {
            viewModel.copyPromptToClipboard()
            withAnimation {
                didCopyPrompt = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    didCopyPrompt = false
                }
            }
        }) {
            Label(didCopyPrompt ? "Copied!" : "Copy Prompt", systemImage: didCopyPrompt ? "checkmark" : "document.on.document")
                .padding()
        }
    }

    // View for long text (URL too long)
    func promptTooLongContent() -> some View {
        VStack {
            Spacer()
            Text("Hey, your entry is long. It'll break the URL. Instead, copy prompt by clicking below and paste into AI of your choice!")
                .padding()

            copyPromptButtonView()

            Spacer()
        }
    }

    var promptTooShortContent: some View {
        Text("Please free write for at minimum 5 minutes first. Then click this. Trust the process.")
    }

    // View for normal text length
    func aiModelsMenu() -> some View {
        VStack {
            Button(action: {
                showingChatMenu = false
                viewModel.openChatGPT()
            }) {
                Text("ChatGPT")
            }
            .buttonStyle(.plain)

            Button(action: {
                showingChatMenu = false
                viewModel.openClaude()
            }) {
                Text("Claude")
            }
            .buttonStyle(.plain)

            copyPromptButtonView()
        }
    }
}

// MARK: FooterView
extension HomeView {
    var footerView: some View {
        HStack {
            // left menu
            Menu {
                Button(action: {
                    showSettings = true
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .padding()
                    .foregroundStyle(.primary)
            }
            .menuOrder(.priority)
            .buttonStyle(.plain)
            .overlay {
                Image(systemName: "line.3.horizontal")
                    .padding()
                    .foregroundStyle(.primary)
            }

            // center menu
            Menu {
                Button("A") { }
                Button("B") { }
                Button("C") { }
            } label: {
                HStack {
                    Image(systemName: "character.cursor.ibeam")
                    Text("written")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .frame(height: 50)
                .foregroundStyle(.primary)
            }
            .menuOrder(.priority)
            .buttonStyle(.plain)
            .overlay {
                HStack {
                    Image(systemName: "character.cursor.ibeam")
                    Text("written")
                }
            }

            HStack {
                // right menu
                Menu {
                    ForEach(timers, id: \.self) { timer in
                        Button("\(viewModel.formattedTime(for: timer))") {
                            viewModel.timeRemaining = Double(timer)
                            if !timerActive {
                                startTimer()
                            }
                        }
                    }
                    Text("How long for?")
                } label: {
                    timerButtonImage
                        .padding()
                        .foregroundStyle(.primary)
                }
                .menuOrder(.priority)
                .buttonStyle(.plain)
                .overlay {
                    timerButtonImage
                        .padding()
                        .foregroundStyle(.primary)
                }

                if timerActive {
                    Button(action: {
                        stopTimer()
                    }) {
                        Image(systemName: "stop.circle")
                    }
                    .padding()
                    .frame(height: 50)
                    .foregroundStyle(.primary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    HomeView()
}
