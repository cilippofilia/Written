//
//  SendButtonView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct SendButtonView: View {
    var body: some View {
        Button(action: {
            print("Sending to AI...")
        }) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "paperplane")
                    .resizable()
                    .frame(width: 20, height: 20)

                Text("Send")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .frame(height: 55)
            .foregroundStyle(Color.white)
        }
        .glassEffect(.regular.tint(.blue).interactive())
    }
}

#Preview {
    SendButtonView()
}
