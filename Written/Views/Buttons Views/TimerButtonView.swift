//
//  TimerButtonView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct TimerButtonView: View {
    @Environment(HomeViewModel.self) var viewModel
    
    let timers: [Int] = [5, 300, 600, 900, 1200, 1500, 1800]
    
    var body: some View {
        Group {
            if !viewModel.timerActive {
                timerMenuView
            } else {
                pauseResumeButton
                stopButton
            }
        }
    }
    
    @ViewBuilder
    private var timerButtonImage: some View {
        if !viewModel.timerActive {
            Image(systemName: "timer")
        } else if viewModel.timerPaused {
            Image(systemName: "play.circle")
        } else {
            Image(systemName: "pause.circle")
        }
    }
    
    private var timerMenuView: some View {
        Menu {
            ForEach(timers, id: \.self) { timer in
                Button("\(viewModel.formattedTime(for: timer))") {
                    viewModel.timerDuration = Double(timer)
                    viewModel.startTimer()
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
    }
    
    private var pauseResumeButton: some View {
        Button(action: {
            if viewModel.timerPaused {
                viewModel.resumeTimer()
            } else {
                viewModel.pauseTimer()
            }
        }) {
            timerButtonImage
        }
        .padding()
        .frame(height: 50)
        .foregroundStyle(.primary)
        .glassEffect(.regular.interactive())
    }
    
    private var stopButton: some View {
        Button(action: {
            viewModel.stopTimer()
        }) {
            Image(systemName: "stop.circle")
        }
        .padding()
        .frame(height: 50)
        .foregroundStyle(.primary)
        .glassEffect(.regular.interactive())
    }
}

#Preview {
    TimerButtonView()
        .environment(HomeViewModel())
}
