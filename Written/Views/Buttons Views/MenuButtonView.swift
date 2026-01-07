//
//  MenuButtonView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct MenuButtonView: View {
    let showWhyAISheet: Binding<Bool>

    var body: some View {
        Group {
            Menu {
                Text("Prompt types")
                Text("History")
                Divider()
                whyAIButtonView(action: {
                    showWhyAISheet.wrappedValue = true
                })
            } label: {
                Button(
                    "Menu",
                    systemImage: "line.3.horizontal",
                    action: {
                    }
                )
                .labelStyle(.iconOnly)
                .frame(width: 50, height: 50)
            }
            .menuOrder(.priority)
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
        }
    }

    func whyAIButtonView(action: @escaping ActionVoid) -> some View {
        Button(action: action) {
            Label("Why AI?", systemImage: "sparkles")
        }
    }
}

#Preview {
    MenuButtonView(showWhyAISheet: .constant(false))
}
