//
//  TimerButtonView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct TimerButtonView: View {
    @Environment(CountdownViewModel.self) var viewModel

    let timers: [Int] = [5, 300, 600, 900, 1200, 1500, 1800]
    
    var body: some View {
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
    TimerButtonView()
        .environment(CountdownViewModel())
}
