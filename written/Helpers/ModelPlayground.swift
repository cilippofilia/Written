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
        aiChatPrompt
    }
    let prompt = ""
    let response = try await session.respond(to: prompt)
    do {
        let response = try await session.respond(to: prompt)
        print(response.content)
    } catch {
        print("error: \(error)")
        if let error = error as? FoundationModels.LanguageModelSession.GenerationError {
            print("error: \(error.localizedDescription)")
        }
    }
}
