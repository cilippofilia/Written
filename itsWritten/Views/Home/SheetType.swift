//
//  SheetType.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import Foundation
import FoundationModels
import SwiftUI

enum SheetType: Identifiable, Equatable {
    case whyAI
    case chat(
        title: String,
        seedPrompt: String?,
        session: LanguageModelSession,
        config: Binding<ModelConfiguration>,
        responseType: Binding<ModelResponseType>,
        threadId: UUID?,
        initialMessages: [ChatMessage]
    )
    case settings(Binding<ModelConfiguration>, Binding<ModelResponseType>)

    var id: String {
        switch self {
        case .whyAI:
            return "whyAI"
        case .chat:
            return "chat"
        case .settings:
            return "settings"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .whyAI:
            WhyAIView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)

        case .chat(
            let title,
            let seedPrompt,
            let session,
            let config,
            let responseType,
            let threadId,
            let initialMessages
        ):
            NavigationStack {
                ChatView(
                    title: title,
                    seedPrompt: seedPrompt,
                    session: session,
                    configuration: config,
                    responseType: responseType,
                    threadId: threadId,
                    initialMessages: initialMessages
                )
                #if !DEBUG
                .hideSensitiveData()
                #endif
            }
            .background(.ultraThinMaterial)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        case .settings(let config, let responseType):
            NavigationStack {
                ModelSettingsSheet(
                    configuration: config,
                    responseType: responseType
                )
            }
            .background(.ultraThinMaterial)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    static func == (lhs: SheetType, rhs: SheetType) -> Bool {
        return lhs.id == rhs.id
    }
}
