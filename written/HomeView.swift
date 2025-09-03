//
//  HomeView.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import SwiftUI

struct HomeView: View {
    @State private var colorScheme: ColorScheme = .light
    @State private var showSettings = false

    @State var text: String = ""

    @State private var timerActive = false
    @State private var timerPaused = false
    @State private var timerCount = 0
    @State private var timer: Timer? = nil

    let viewModel = HomeViewModel()

    // Initialize with saved theme preference if available
    init() {
        // Load saved color scheme preference
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "light"
        _colorScheme = State(initialValue: savedScheme == "dark" ? .dark : .light)
    }

    var body: some View {
        NavigationStack {
            VStack {
                TextField(
                    "",
                    text: $text,
                    axis: .vertical
                )
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text(viewModel.getRandomPlaceholderText())
                            .foregroundStyle(.secondary)
                            .bold()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Spacer()

                HStack {
                    sendButton
                    Spacer()
                    if timerActive || timerPaused {
                        stopButton
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                    }
                    timerButton
                    settingsButton
                }
                .padding()
                .animation(.spring(), value: timerActive || timerPaused)
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

extension HomeView {
    var settingsButton: some View {
        Button(action: {
            print("Gear tapped")
            showSettings = true
        }) {
            Image(systemName: "gearshape")
        }
        .buttonStyle(.glass)
    }

    var sendButton: some View {
        Button(action: {
            print("Sending to AI model...")
        }) {
            Label {
                Text("Send")
            } icon: {
                Image(systemName: "paperplane")
            }
        }
        .buttonStyle(.glass)
    }

    var stopButton: some View {
        Button(action: {
            timer?.invalidate()
            timer = nil
            timerActive = false
            timerPaused = false
            timerCount = 0
            print("Timer stopped and reset.")
        }) {
            Image(systemName: "stop.circle")
        }
        .frame(height: 44)
        .buttonStyle(.glass)
    }

    var timerButton: some View {
        Button(action: {
            if !timerActive {
                timerActive = true
                timerPaused = false
                timerCount = 0
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    timerCount += 1
                    print("Timer: \(timerCount)s")
                }
            } else if timerActive && !timerPaused {
                timer?.invalidate()
                timerPaused = true
            } else if timerActive && timerPaused {
                timerPaused = false
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    timerCount += 1
                    print("Timer: \(timerCount)s")
                }
            }
        }) {
            if !timerActive {
                Image(systemName: "timer")
            } else if timerPaused {
                Image(systemName: "play.circle")
            } else {
                Image(systemName: "pause.circle")
            }
        }
        .frame(height: 44)
        .buttonStyle(.glass)
    }
}

#Preview {
    HomeView()
}
