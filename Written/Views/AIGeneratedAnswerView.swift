//
//  AIGeneratedAnswerView.swift
//  written
//
//  Created by Filippo Cilia on 05/01/2026.
//

import SwiftUI

struct AIGeneratedAnswerView: View {
    let answer: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(answer)
                .padding()
                .padding(.vertical, 50)
                .foregroundStyle(.primary)
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .mask {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)

                Rectangle()

                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
            }
        }
    }
}

#Preview {
    AIGeneratedAnswerView(answer: loremIpsum)
}
