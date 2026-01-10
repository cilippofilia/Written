//
//  CountdownViewModelTests.swift
//  WrittenTests
//
//  Created by Filippo Cilia on 10/01/2026.
//

import Testing
@testable import Written
import SwiftUI

@Suite("CountdownViewModel tests")
struct CountdownViewModelTests {

    @Test("Start timer sets active state and endTime")
    func startTimerSetsState() async throws {
        let vm = await CountdownViewModel()
        await vm.startTimer(duration: 1)
        #expect(await vm.timerActive == true)
        #expect(await vm.timerPaused == false)
        #expect(await vm.timerExpired == false)
        #expect(await vm.endTime != nil)
    }

    @Test("Pause freezes remaining time")
    func pauseFreezesRemainingTime() async throws {
        let vm = await CountdownViewModel()
        await vm.startTimer(duration: 2)
        try? await Task.sleep(for: .milliseconds(200))
        let beforePause = await vm.timeRemaining(at: .now)
        await vm.pauseTimer()
        let paused1 = await vm.timeRemaining(at: .now)
        try? await Task.sleep(for: .milliseconds(300))
        let paused2 = await vm.timeRemaining(at: .now)
        #expect(paused1 == paused2, "Remaining time should not change while paused")
        #expect(paused1 <= beforePause && paused1 >= 0)
        #expect(await vm.timerPaused == true)
    }

    @Test("Resume restores countdown from paused remaining time")
    func resumeRestoresFromPaused() async throws {
        let vm = await CountdownViewModel()
        await vm.startTimer(duration: 1.5)
        try? await Task.sleep(for: .milliseconds(300))
        await vm.pauseTimer()
        let pausedRemaining = await vm.timeRemaining(at: .now)
        try? await Task.sleep(for: .milliseconds(300))
        await vm.resumeTimer()
        let afterResume = await vm.timeRemaining(at: .now)
        #expect(afterResume <= pausedRemaining + 0.05)
        #expect(await vm.timerPaused == false)
        #expect(await vm.timerActive == true)
    }

    @Test("Stop resets state")
    func stopResetsState() async throws {
        let vm = await CountdownViewModel()
        await vm.startTimer(duration: 1)
        await vm.stopTimer()
        #expect(await vm.timerActive == false)
        #expect(await vm.timerPaused == false)
        #expect(await vm.endTime == nil)
        #expect(await vm.timerExpired == false)
    }
}
