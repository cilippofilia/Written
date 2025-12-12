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

    @State private var text: String = ""
    @State private var prompt: String = ""

    @State private var timerActive: Bool = false
    @State private var timerPaused: Bool = false

    @State private var showTimeIsUpAlert: Bool = false
    @State private var showWhyAI: Bool = false
    @State private var showSettings: Bool = false

    @State private var didCopyPrompt: Bool = false

    let timers: [Int] = [5, 300, 600, 900, 1200, 1500, 1800]

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
                GlassEffectContainer {
                    footerView
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
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
        TextEditor(text: $text)
            .focused($isFocused)
            .padding(.leading, 8)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(viewModel.placeholderText)
                        .foregroundStyle(.secondary)
                        .padding(.leading)
                        .padding(.top, 8)
                        .opacity(isFocused ? 0.2 : 1)
                        .animation(.easeInOut, value: $isFocused.wrappedValue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .scrollContentBackground(.hidden)
    }

    var settingsButtonView: some View {
        Button(action: {
            showSettings = true
        }) {
            HStack {
                Image(systemName: "gear")
                Text("Settings")
            }
        }
    }

    var whyAIButtonView: some View {
        Button(action: {
            showWhyAI = true
        }) {
            HStack {
                Image(systemName: "sparkles")
                Text("Why AI?")
            }
        }
    }
}

// MARK: FooterView
extension HomeView {
    var footerView: some View {
        HStack {
            // left menu
            Menu {
                settingsButtonView
                whyAIButtonView
            } label: {
                Image(systemName: "line.3.horizontal")
                    .padding()
                    .frame(height: 50)
                    .foregroundStyle(.primary)
            }
            .menuOrder(.priority)
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())

            // center button
            Button(action: {
                print("Sending to AI...")
            }) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "paperplane")
                        .resizable()
                        .frame(width: 20, height: 20)

                    Text("Send")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .frame(height: 55)
                .foregroundStyle(Color.white)
            }
            .glassEffect(.regular.tint(.blue).interactive())

            // right menu
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
                        .frame(height: 50)
                        .foregroundStyle(.primary)
                }
                .menuOrder(.priority)
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
            } else {
                Button(action: {
                    if !timerActive || timerPaused {
                        startTimer()
                    } else {
                        pauseTimer()
                    }
                }) {
                    timerButtonImage
                }
                .padding()
                .frame(height: 50)
                .foregroundStyle(.primary)
                .glassEffect(.regular.interactive())
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
                .glassEffect(.regular.interactive())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
}
