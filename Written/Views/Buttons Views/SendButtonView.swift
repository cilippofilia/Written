//
//  SendButtonView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct SendButtonView: View {
    let isResponding: Bool
    let isInputEmpty: Bool
    let sendAction: () -> Void

    var body: some View {
        Button(action: {
            sendAction()
        }) {
            Color.clear
                .contentShape(.rect)
                .overlay {
                    if isResponding == true {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    } else {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "paperplane")
                                .resizable()
                                .frame(width: 20, height: 20)

                            Text("Send")
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .frame(height: 55)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(isResponding || isInputEmpty ? .secondary : .blue).interactive())
        .animation(.easeInOut, value: isResponding)
        .animation(.easeInOut, value: isInputEmpty)
    }
}

#Preview {
    SendButtonView(isResponding: true, isInputEmpty: true, sendAction: { })
}
