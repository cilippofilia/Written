//
//  CountdownView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct CountdownView: View {
    @Environment(HomeViewModel.self) var viewModel
    @Binding var showTimeIsUpAlert: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = viewModel.timeRemaining(at: context.date)
            HStack {
                Image(systemName: "timer")
                Text(viewModel.formattedTime(for: Int(remaining)))
                    .contentTransition(.numericText(value: remaining))
                    .animation(.bouncy, value: remaining)
                    .monospacedDigit()
            }
            .font(.caption).bold()
            .foregroundStyle(.secondary)
            .onChange(of: remaining) { _, newValue in
                if newValue <= 0 && viewModel.timerActive && !viewModel.timerPaused {
                    showTimeIsUpAlert = true
                    viewModel.stopTimer()
                }
            }
        }
    }
}

#Preview {
    CountdownView(showTimeIsUpAlert: .constant(false))
        .environment(HomeViewModel())
}
