//
//  WhyAIView.swift
//  written
//
//  Created by Filippo Cilia on 03/11/2025.
//

import SwiftUI

struct WhyAIView: View {
    let action: ActionVoid
    let analogy: String = """

    Think of most AI services like mailing a letter - once you send it, the post office has a copy and can read it. Apple's AI is like whispering to yourself (on-device) or using a secure vault that destroys the contents immediately after reading it to you (Private Cloud Compute). Not even Apple keeps a copy.
        
    """
    let explanation: String = """
    This makes Apple's foundation model uniquely privacy-focused compared to competitors who typically retain and may use your data for model training or other purposes.
    """

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Why using ")

                Image(systemName: "apple.intelligence")
                    .symbolRenderingMode(.multicolor)

                Link("Apple Intelligence", destination: URL(string: "https://www.apple.com/apple-intelligence/")!)
                    .tint(.primary)
                    .bold()
                    .underline(true, color: .secondary)

                Text("?")
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text(analogy)
            Text(explanation)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }
}

#Preview {
    WhyAIView(action: { })
}
