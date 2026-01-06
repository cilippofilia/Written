//
//  CheckingAvailabilityView.swift
//  Written
//
//  Created by Filippo Cilia on 06/01/2026.
//

import SwiftUI

struct CheckingAvailabilityView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)

            Text("Checking Availability")
                .font(.title2)
                .bold()

            Text("Please wait while we check Apple Intelligence availability on this device.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    CheckingAvailabilityView()
}
