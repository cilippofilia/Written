//
//  CountDownViewModel.swift
//  Written
//
//  Created by Filippo Cilia on 08/01/2026.
//

import Foundation

@Observable
@MainActor
final class CountdownViewModel {
    var endTime: Date?
    var timerActive = false
    var timerPaused = false
    var timerExpired = false

    private var expirationCheckTask: Task<Void, Never>?

    func startTimer(duration: TimeInterval) {
        endTime = Date.now.addingTimeInterval(duration)
        timerActive = true
        timerPaused = false
        timerExpired = false

        startExpirationCheck()
    }

    func pauseTimer() {
        timerPaused = true
        expirationCheckTask?.cancel()
    }

    func resumeTimer() {
        timerPaused = false
        startExpirationCheck()
    }

    func stopTimer() {
        timerActive = false
        timerPaused = false
        endTime = nil
        expirationCheckTask?.cancel()
    }

    func timeRemaining(at date: Date) -> TimeInterval {
        guard let endTime else { return 0 }
        return endTime.timeIntervalSince(date)
    }

    func formattedTime(for seconds: Int) -> String {
        let absoluteSeconds = abs(seconds)
        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60
        let secs = absoluteSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func startExpirationCheck() {
        expirationCheckTask?.cancel()
        expirationCheckTask = Task {
            while !Task.isCancelled && timerActive && !timerPaused {
                let remaining = timeRemaining(at: .now)
                if remaining < 1 {
                    timerExpired = true
                    stopTimer()
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
