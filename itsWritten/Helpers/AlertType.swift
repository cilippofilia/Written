//
//  AlertType.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import FoundationModels

enum AlertType: Identifiable {
    case timeUp
    case aiGeneration(title: String, message: String)

    var id: String {
        switch self {
        case .timeUp:
            return "timeUp"
        case .aiGeneration:
            return "aiGeneration"
        }
    }

    var title: String {
        switch self {
        case .timeUp:
            return "Time's Up!"
        case .aiGeneration(let title, _):
            return title
        }
    }

    var message: String {
        switch self {
        case .timeUp:
            return "Your countdown timer has finished."
        case .aiGeneration(_, let message):
            return message
        }
    }

    var buttonText: String {
        "OK"
    }
}

extension AlertType {
    /// Builds a friendly alert for a Foundation Models generation failure.
    static func aiGenerationAlert(for error: LanguageModelSession.GenerationError) -> AlertType {
        var title = "Response Error"
        var message = error.localizedDescription
        var appendsRecoverySuggestion = true

        switch error {
        case .guardrailViolation(let context):
            title = "Guardrail Violation"
            message = context.debugDescription
        case .decodingFailure(let context):
            title = "Decoding Failure"
            message = context.debugDescription
        case .rateLimited(let context):
            title = "Rate Limited"
            message = context.debugDescription
        case .assetsUnavailable:
            title = "Apple Intelligence Unavailable"
            message = "The on-device model isn't ready. Make sure Apple Intelligence is turned on in Settings and its model has finished downloading, then try again."
            appendsRecoverySuggestion = false
        case .exceededContextWindowSize:
            title = "Conversation Too Long"
            message = "This message is too long for the on-device model to process. Try shortening it or starting a new chat."
            appendsRecoverySuggestion = false
        default:
            break
        }

        if appendsRecoverySuggestion, let recoverySuggestion = error.recoverySuggestion {
            message += "\n\n\(recoverySuggestion)"
            if let helpAnchor = error.helpAnchor {
                message += "\(helpAnchor)"
            }
        }

        return .aiGeneration(title: title, message: message)
    }
}
