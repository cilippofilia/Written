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
    case settings(Binding<ModelConfiguration>, Binding<ModelResponseType>)

    var id: String {
        switch self {
        case .whyAI:
            return "whyAI"
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
