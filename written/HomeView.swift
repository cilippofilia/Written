//
//  HomeView.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import SwiftUI

public typealias ActionVoid = () -> Void

struct HomeView: View {
    @Namespace private var namespace
    @Namespace private var namespace2

    @State private var showMenu: Bool = false
    @State private var timerActive: Bool = false
    @State private var timerPaused: Bool = false
    @State private var showTimeIsUpAlert: Bool = false
    @State private var showingChatMenu: Bool = false
    @State private var didCopyPrompt: Bool = false

    let timers: [Int] = [2, 300, 600, 900, 1200, 1500, 1800]

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

                HStack {
                    menuButtonView {
                        showMenu = true
                    }

                    sendButtonView {
                        showingChatMenu = true
                        // Calculate potential URL lengths
                        viewModel.calculateURLLenghts()
                    }
                    .animation(.spring, value: timerActive || timerPaused)
                    .popover(isPresented: $showingChatMenu) {
                        popoverSendContent()
                    }

                    GlassEffectContainer(spacing: 50) {
                        HStack {
                            if !timerActive {
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
                                        .glassEffect(.regular.interactive())
                                        .glassEffectID(2, in: namespace)
                                        .glassEffectTransition(.matchedGeometry(properties: .position, anchor: .leading))
                                }
                                .buttonStyle(.plain)
                            } else {
                                timerButtonImage
                                    .padding()
                                    .frame(height: 50)
                                    .foregroundStyle(.primary)
                                    .glassEffect(.regular.interactive())
                                    .glassEffectID(2, in: namespace)
                                    .glassEffectTransition(.matchedGeometry(properties: .position, anchor: .leading))
                                    .onTapGesture {
                                        if !timerActive || timerPaused {
                                            startTimer()
                                        } else {
                                            pauseTimer()
                                        }
                                    }
                            }

                            if timerActive {
                                stopButtonView {
                                    stopTimer()
                                }
                                .glassEffectID(1, in: namespace)
                                .glassEffectTransition(.matchedGeometry)
                            }
                        }
                    }
                    .animation(.spring, value: timerActive || timerPaused)
                }
                .padding(.horizontal)
            }
            .navigationDestination(isPresented: $showMenu) {
                MenuView()
            }
            .onAppear {
                viewModel.setRandomPlaceholderText()
            }
            .background {
                homeBackground()
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
    func homeBackground() -> some View {
        TimelineView(.animation) { timeline in
            let x = (sin(timeline.date.timeIntervalSince1970) + 1) / 2
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, Float(x)], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ], colors: [
                .indigo, .cyan, .indigo,
                .purple, .white, .purple,
                .purple, .pink, .purple
            ])
            .opacity(0.4)
            .ignoresSafeArea(.all)
        }
    }

    func menuButtonView(
        _ action: @escaping ActionVoid
    ) -> some View {
        Image(systemName: "line.3.horizontal")
            .padding()
            .frame(height: 50)
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive())
            .onTapGesture {
                action()
            }
    }

    func sendButtonView(
        _ action: @escaping ActionVoid
    ) -> some View {
        HStack {
            Image(systemName: "character.cursor.ibeam")
            Text("written")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive().tint(.blue))
        .onTapGesture {
            action()
        }
    }

    func stopButtonView(
        _ action: @escaping ActionVoid
    ) -> some View {
        Image(systemName: "stop.circle")
            .padding()
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive())
            .onTapGesture {
                action()
            }
    }

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
        .ignoresSafeArea(.container)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    func popoverSendContent() -> some View {
        if viewModel.isUrlTooLong {
            promptTooLongContent()
        } else if viewModel.text.count < 5 { // TODO: change this to 350
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
                .glassEffect(.regular.interactive())
        }
        .animation(.spring, value: didCopyPrompt)
    }

    func promptTooLongContent() -> some View {
        VStack {
            Spacer()
            // View for long text (URL too long)
            Text("Hey, your entry is long. It'll break the URL. Instead, copy prompt by clicking below and paste into AI of your choice!")
                .padding()

            copyPromptButtonView()

            Spacer()
        }
    }

    var promptTooShortContent: some View {
        Text("Please free write for at minimum 5 minutes first. Then click this. Trust the process.")
    }

    func aiModelsMenu() -> some View {
        VStack {
            // View for normal text length
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

#Preview {
    HomeView()
}
