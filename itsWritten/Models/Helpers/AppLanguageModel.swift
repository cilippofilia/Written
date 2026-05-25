//
//  AppLanguageModel.swift
//  itsWritten
//
//  Created by Filippo Cilia on 23/02/2026.
//

import FoundationModels

/// Shared app-level configuration for SystemLanguageModel and sessions.
enum AppLanguageModel {
    static let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
    static let tools: [any Tool] = [
        PubMedSearchTool(),
        ClinicalTrialsSearchTool(),
        OpenFDADrugTool()
    ]

    static func session(instructions: String? = nil) -> LanguageModelSession {
        if let instructions, instructions.isReallyEmpty == false {
            return LanguageModelSession(model: model, tools: tools, instructions: instructions)
        }

        return LanguageModelSession(model: model, tools: tools)
    }

    static func sessionWithoutTools(instructions: String? = nil) -> LanguageModelSession {
        if let instructions, instructions.isReallyEmpty == false {
            return LanguageModelSession(model: model, tools: [], instructions: instructions)
        }

        return LanguageModelSession(model: model, tools: [])
    }

    static func session(transcript: Transcript) -> LanguageModelSession {
        LanguageModelSession(model: model, tools: tools, transcript: transcript)
    }

    static func sessionWithoutTools(transcript: Transcript) -> LanguageModelSession {
        LanguageModelSession(model: model, tools: [], transcript: transcript)
    }
}
