//
//  CountdownView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct CountdownView: View {
    @Environment(CountdownViewModel.self) var viewModel

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
            .font(.caption)
            .bold()
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    CountdownView()
        .environment(CountdownViewModel())
}
