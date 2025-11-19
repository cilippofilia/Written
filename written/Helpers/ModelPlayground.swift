//
//  ModelPlayground.swift
//  written
//
//  Created by Filippo Cilia on 29/10/2025.
//

import FoundationModels
import Playgrounds
import SwiftUI

#Playground {
    let session = LanguageModelSession {
        reflectivePrompt
    }
    let userInput = "i've been feeling really down today because i had a fight with my mum. i know she means good for me but sometimes it feels like she's projecting her own insecurities onto me, trying to dictate me. and when i push back, she gets frustrated. i know we're okay but i'm just feeling down about it and i'd like some help processing it"
    let response = try await session.respond(to: userInput)
    var errorResponse = ""
    do {
        let response = try await session.respond(to: userInput)
        print(response.content)
    } catch let error as LanguageModelSession.GenerationError {
        switch error {
        case .guardrailViolation(let context):
            errorResponse = "Guardrail violation: \(context.debugDescription)"
        case .decodingFailure(let context):
            errorResponse = "Decoding failure: \(context.debugDescription)"
        case .rateLimited(let context):
            errorResponse = "Rate limited: \(context.debugDescription)"
        default:
            errorResponse = "Other error \(error.localizedDescription)"
        }
        if let failureReason = error.failureReason {
            errorResponse += "\n\n(failure reason: \(failureReason))"
        }
        if let recoverySuggestion = error.recoverySuggestion {
            errorResponse += "\n\n(recovery suggestion: \(recoverySuggestion))"
        }
    } catch {
        print("error: \(error)")
        if let error = error as? FoundationModels.LanguageModelSession.GenerationError {
            print("error: \(error.localizedDescription)")
        }
    }
}
