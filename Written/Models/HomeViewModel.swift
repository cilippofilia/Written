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
    var selectedAIModel: AIModel
    var session: LanguageModelSession?

    init(selectedPrompt: AIModel? = nil) {
        self.selectedAIModel = selectedPrompt ?? aiModelList.first!
    }

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
    
    let aiModelList: [AIModel] = [
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
    
    func prepareInitialState(storedModelID: String) {
        setRandomPlaceholderText()

        if let match = aiModelList.first(where: { $0.id == storedModelID }) {
            selectedAIModel = match
        } else if let first = aiModelList.first {
            selectedAIModel = first
        }

        prepareSessionIfNeeded()
    }

    func updateSelection(to prompt: AIModel) {
        selectedAIModel = prompt
        prepareSessionIfNeeded()
    }

    private func prepareSessionIfNeeded() {
        if session == nil {
            session = LanguageModelSession(
                instructions: { selectedAIModel.prompt }
            )
        }
    }
}

enum AlertType {
    case inputEmpty
    case lowCharacterCount
    case aiGeneration(title: String, message: String)
    case timeUp

    var title: String {
        switch self {
        case .inputEmpty, .lowCharacterCount:
            return "OOPS!"
        case .aiGeneration(let title, _):
            return title
        case .timeUp:
            return "Time is up!"
        }
    }

    var message: String {
        switch self {
        case .inputEmpty:
            return "Your input is empty.\nStart the timer, set it to the minimum and start typing away!"
        case .lowCharacterCount:
            return "Your input is too short. Try adding a few more words before sending."
        case .aiGeneration(_, let message):
            return message
        case .timeUp:
            return "Feel free to finish up your thoughts and then press Send!"
        }
    }

    var buttonText: String {
        switch self {
        case .inputEmpty, .lowCharacterCount:
            return "Dismiss"
        case .aiGeneration, .timeUp:
            return "Got it!"
        }
    }
}
