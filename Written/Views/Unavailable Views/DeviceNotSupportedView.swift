//
//  DeviceNotSupportedView.swift
//  Written
//
//  Created by Filippo Cilia on 06/01/2026.
//

import SwiftUI

struct DeviceNotSupportedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Device Not Supported")
                .font(.title2)
                .bold()

            Text("This device does not support Apple Intelligence. This feature requires a compatible device with an A17 Pro chip or later.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Compatible devices include iPhone 15 Pro, iPhone 15 Pro Max, and later models.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 2) {
                Text("For more info:")
                Link("Apple Intelligence", destination: URL(string: "https://www.apple.com/apple-intelligence/")!)
                    .bold()
                    .underline(true, pattern: .solid, color: Color.secondary.opacity(0.2))
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    DeviceNotSupportedView()
}
