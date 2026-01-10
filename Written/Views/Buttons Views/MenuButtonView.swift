//
//  MenuButtonView.swift
//  written
//
//  Created by Filippo Cilia on 12/12/2025.
//

import SwiftUI

struct MenuButtonView: View {
    let selectedModel: Binding<AIModel>
    let aiModels: [AIModel]
    let showWhyAISheet: Binding<Bool>

    var body: some View {
        Group {
            Menu {
                // TODO: ideas to implement
                Label("Onboarding", systemImage: "book.pages")
                Label("History", systemImage: "clock.arrow.circlepath")

                Menu {
                    Picker("", selection: selectedModel) {
                        ForEach(aiModels, id: \.self) { model in
                            Text(model.title)
                        }
                    }
                } label: {
                    Label("Model types", systemImage: "brain")
                }

                Divider()

                // Why AI
                Button(action: {
                    showWhyAISheet.wrappedValue = true
                }) {
                    Label("Why AI?", systemImage: "sparkles")
                }

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
}

#Preview {
    MenuButtonView(
        selectedModel: .constant(AIModel(id: "", title: "", prompt: "")),
        aiModels: [],
        showWhyAISheet: .constant(false)
    )
}
