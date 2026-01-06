//
//  RespondingIndicator.swift
//  written
//
//  Created by Filippo Cilia on 06/01/2026.
//

import SwiftUI

struct RespondingIndicator: View {
    @State private var animationPhase = 0.0
    @State private var scaleAmount = 1.0

    var body: some View {
        Image(systemName: "brain")
            .font(.largeTitle)
            .symbolRenderingMode(.multicolor)
            .foregroundStyle(foregroundColor)
            .hueRotation(.degrees(animationPhase * 360))
            .scaleEffect(scaleAmount)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 16))
            .scaleEffect(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(.ultraThinMaterial.opacity(0.5))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    scaleAmount = 1.2
                }

                withAnimation(
                    .linear(duration: 3)
                    .repeatForever(autoreverses: false)
                ) {
                    animationPhase = 1.0
                }
            }
    }

    var foregroundColor: LinearGradient {
        LinearGradient(
            colors: [
                .blue,
                .purple,
                .pink,
                .orange,
                .blue
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
}

#Preview {
    RespondingIndicator()
}
