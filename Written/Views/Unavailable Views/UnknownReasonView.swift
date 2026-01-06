//
//  UnknownReasonView.swift
//  Written
//
//  Created by Filippo Cilia on 06/01/2026.
//

import SwiftUI

struct UnknownReasonView: View {
    let action: ActionVoid

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("Unknown Status")
                .font(.title2)
                .bold()

            Text("An unexpected status was encountered. Please try restarting the app.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    UnknownReasonView(action: { })
}
