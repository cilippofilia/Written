//
//  CountDownViewModel.swift
//  Written
//
//  Created by Filippo Cilia on 08/01/2026.
//

import SwiftUI

@Observable
@MainActor
final class CountdownViewModel {
    var endTime: Date?
    var timerActive = false
    var timerPaused = false
    var timerExpired = false
    private var pausedRemaining: TimeInterval?

    private var expirationCheckTask: Task<Void, Never>?

    func startTimer(duration: TimeInterval) {
        withAnimation(.smooth) {
            endTime = Date.now.addingTimeInterval(duration)
            timerActive = true
            timerPaused = false
            timerExpired = false
            pausedRemaining = nil

            startExpirationCheck()
        }
    }

    func pauseTimer() {
        withAnimation(.smooth) {
            let remaining = timeRemaining(at: .now)
            pausedRemaining = max(0, remaining)
            timerPaused = true
            expirationCheckTask?.cancel()
        }
    }

    func resumeTimer() {
        withAnimation(.smooth) {
            let remaining = pausedRemaining ?? timeRemaining(at: .now)
            endTime = Date.now.addingTimeInterval(remaining)
            timerPaused = false
            pausedRemaining = nil
            startExpirationCheck()
        }
    }

    func stopTimer() {
        withAnimation(.smooth) {
            timerActive = false
            timerPaused = false
            endTime = nil
            pausedRemaining = nil
            timerExpired = false
            expirationCheckTask?.cancel()
        }
    }

    func timeRemaining(at date: Date) -> TimeInterval {
        if timerPaused, let pausedRemaining {
            return pausedRemaining
        }
        guard let endTime else { return 0 }
        return endTime.timeIntervalSince(date)
    }

    func formattedTime(for timer: Int) -> String {
        let minutes = timer / 60
        let seconds = timer % 60
        let minutesString = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        let secondsString = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        return "\(minutesString):\(secondsString)"
    }

    private func startExpirationCheck() {
        expirationCheckTask?.cancel()
        expirationCheckTask = Task {
            while !Task.isCancelled && timerActive && !timerPaused {
                let remaining = timeRemaining(at: .now)
                if remaining <= 0 && !timerPaused {
                    timerExpired = true
                    stopTimer()
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}

