//
//  TimerMenuButtonView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct TimerMenuButtonView: View {
    @Environment(CountdownViewModel.self) var viewModel

    let timers: [Int] = [5, 300, 600, 900, 1200, 1500, 1800]
    
    var body: some View {
        Group {
            if viewModel.timerActive || viewModel.timerPaused {
                HStack(spacing: 12) {
                    if viewModel.timerPaused {
                        Button(action: {
                            viewModel.resumeTimer()
                        }) {
                            Image(systemName: "play.circle")
                                .padding()
                                .frame(height: 50)
                                .foregroundStyle(.primary)
                                .glassEffect(.regular.interactive())
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            viewModel.pauseTimer()
                        }) {
                            Image(systemName: "pause.circle")
                                .padding()
                                .frame(height: 50)
                                .foregroundStyle(.primary)
                                .glassEffect(.regular.interactive())
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: {
                        viewModel.stopTimer()
                    }) {
                        Image(systemName: "stop.circle")
                            .padding()
                            .frame(height: 50)
                            .foregroundStyle(.primary)
                            .glassEffect(.regular.interactive())
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                menuView
            }
        }
    }

    @ViewBuilder
    var menuView: some View {
        Menu {
            ForEach(timers, id: \.self) { timer in
                Button {
                    viewModel.startTimer(duration: TimeInterval(timer))
                } label: {
                    Text(viewModel.formattedTime(for: timer))
                }
            }

            Divider()

            Text("How long for?")
        } label: {
            Image(systemName: viewModel.timerActive ? "stop.circle" : "timer")
                .padding()
                .frame(height: 50)
                .foregroundStyle(.primary)
                .glassEffect(.regular.interactive())
        }
        .buttonStyle(.plain)
        .menuOrder(.priority)
        .contentTransition(.symbolEffect(.replace))
        .glassEffect(.regular.interactive())
    }
}

#Preview {
    TimerMenuButtonView()
        .environment(CountdownViewModel())
}
