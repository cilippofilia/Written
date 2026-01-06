//
//  HomeViewModel.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import SwiftUI

@MainActor
@Observable
public class HomeViewModel {
    var placeholderText: String = ""
    var timerDuration: TimeInterval = 0
    var timerStartDate: Date?
    var timerPausedElapsed: TimeInterval = 0
    var timerActive: Bool = false
    var timerPaused: Bool = false

    // AI session & response state
    var aiAnswer: String = ""
    var errorTitle: String? = nil
    var errorMessage: String? = nil
    var showAIGenerationAlert: Bool = false
    var showAIGeneratedAnswer: Bool = false
    var isResponding: Bool = false

    // Private session
    private var session: LanguageModelSession? = nil

    let placeholderOptions: [String] = [
        "Begin writing",
        "Pick a thought and go",
        "Start typing",
        "What's on your mind",
        "Just start",
        "Type your first thought",
        "Start with one sentence",
        "Just say it"
    ]

    let promptOptions: [String] = [
        reflectivePrompt,
        insightfulPrompt,
        actionableSuggestionPrompt,
        validatingPrompt,
        challengingPrompt
    ]

    func formattedTime(for timer: Int) -> String {
        let minutes = timer / 60
        let seconds = timer % 60
        let minutesString = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        let secondsString = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        return "\(minutesString):\(secondsString)"
    }

    func timeRemaining(at date: Date) -> TimeInterval {
        guard timerActive, let startDate = timerStartDate else {
            return timerPaused ? timerPausedElapsed : timerDuration
        }
        
        if timerPaused {
            return timerPausedElapsed
        }
        
        let elapsed = date.timeIntervalSince(startDate)
        let remaining = timerDuration - elapsed
        return max(0, remaining)
    }
    
    var formattedTimeLeft: String {
        let remaining = timeRemaining(at: Date())
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        let minutesString = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        let secondsString = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        return "\(minutesString):\(secondsString)"
    }

    func setRandomPlaceholderText() {
        let text = placeholderOptions.randomElement() ?? "Begin writing"
        placeholderText = text + "..."
    }
    
    func startTimer() {
        guard timerDuration > 0 else { return }
        timerActive = true
        timerPaused = false
        timerStartDate = Date()
        timerPausedElapsed = 0
    }
    
    func pauseTimer() {
        guard let startDate = timerStartDate else { return }
        timerPaused = true
        let elapsed = Date().timeIntervalSince(startDate)
        timerPausedElapsed = max(0, timerDuration - elapsed)
    }
    
    func resumeTimer() {
        guard timerPaused && timerPausedElapsed > 0 else { return }
        timerPaused = false
        timerDuration = timerPausedElapsed
        timerStartDate = Date()
        timerPausedElapsed = 0
    }
    
    func stopTimer() {
        timerDuration = 0
        timerStartDate = nil
        timerPausedElapsed = 0
        timerActive = false
        timerPaused = false
    }
    
    // MARK: - AI Send Logic
    func send(text: String) async {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        resetAlerts()
        prepareSessionIfNeeded()
        guard let session else { return }

        do {
            isResponding = session.isResponding
            let stream = session.streamResponse(to: input)
            for try await partial in stream {
                aiAnswer = partial.content
                showAIGeneratedAnswer = true
                showAIGenerationAlert = false
            }
        } catch let error as LanguageModelSession.GenerationError {
            handleGenerationError(error)
        } catch {
            if let error = error as? FoundationModels.LanguageModelSession.GenerationError {
                errorMessage = "Error: \(error.localizedDescription)"
            } else {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            showAIGenerationAlert = true
        }
        isResponding = false
    }

    private func prepareSessionIfNeeded() {
        if session == nil {
            session = LanguageModelSession(
                instructions: { self.promptOptions.first }
            )
        }
    }

    private func resetAlerts() {
        errorMessage = nil
        showAIGenerationAlert = false
        showAIGeneratedAnswer = false
    }

    private func handleGenerationError(_ error: LanguageModelSession.GenerationError) {
        switch error {
        case .guardrailViolation(let context):
            errorTitle = "Guardrail Violation"
            errorMessage = "\(context.debugDescription)"
        case .decodingFailure(let context):
            errorTitle = "Decoding Failure"
            errorMessage = "\(context.debugDescription)"
        case .rateLimited(let context):
            errorTitle = "Rate Limited"
            errorMessage = "\(context.debugDescription)"
        default:
            errorTitle = "Response Error"
            errorMessage = "\(error.localizedDescription)"
        }
        if let recoverySuggestion = error.recoverySuggestion {
            let base = errorMessage ?? ""
            errorMessage = base + "\n\n\(recoverySuggestion)" + "\(error.helpAnchor ?? "")"
        }
        showAIGenerationAlert = true
    }
}
