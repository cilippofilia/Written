//
//  AvailabilityView.swift
//  written
//
//  Created by Filippo Cilia on 25/10/2025.
//

import FoundationModels
import SwiftUI

struct AvailabilityView: View {
    @State private var homeVM: HomeViewModel = HomeViewModel()

    private var model = SystemLanguageModel.default

    var body: some View {
        Group {
            switch model.availability {
            case .available:
                HomeView()
                    .environment(homeVM)
            case .unavailable(.modelNotReady):
                Text("This model is not ready yet. Please try again later.")
            case .unavailable(.appleIntelligenceNotEnabled):
                Text("Apple Intelligence is not enabled on this device. Please turn on Apple Intelligence.")
            case .unavailable(.deviceNotEligible):
                Text("This device is not eligible for Apple Intelligence.")
            case .unavailable(let other):
                Text("Unavailable: " + String(describing: other))
            @unknown default:
                Text("Unknown")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AvailabilityView()
}
