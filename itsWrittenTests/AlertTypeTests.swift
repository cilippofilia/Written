//
//  AlertTypeTests.swift
//  WrittenTests
//
//  Created by Filippo Cilia on 09/08/2026.
//

import FoundationModels
import XCTest
@testable import itsWritten

final class AlertTypeTests: XCTestCase {
    func testAssetsUnavailableProducesFriendlyAlert() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "Model is unavailable")
        let error = LanguageModelSession.GenerationError.assetsUnavailable(context)

        let alert = AlertType.aiGenerationAlert(for: error)

        XCTAssertEqual(alert.title, "Apple Intelligence Unavailable")
        XCTAssertTrue(alert.message.localizedStandardContains("Apple Intelligence"))
        XCTAssertTrue(alert.message.localizedStandardContains("Settings"))
    }

    func testExceededContextWindowSizeProducesFriendlyAlert() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "Too many tokens")
        let error = LanguageModelSession.GenerationError.exceededContextWindowSize(context)

        let alert = AlertType.aiGenerationAlert(for: error)

        XCTAssertEqual(alert.title, "Conversation Too Long")
        XCTAssertTrue(alert.message.localizedStandardContains("new chat"))
    }

    func testGuardrailViolationUsesDebugDescription() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "Blocked content")
        let error = LanguageModelSession.GenerationError.guardrailViolation(context)

        let alert = AlertType.aiGenerationAlert(for: error)

        XCTAssertEqual(alert.title, "Guardrail Violation")
        XCTAssertTrue(alert.message.hasPrefix("Blocked content"))
    }

    func testRateLimitedUsesDebugDescription() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "Too many requests")
        let error = LanguageModelSession.GenerationError.rateLimited(context)

        let alert = AlertType.aiGenerationAlert(for: error)

        XCTAssertEqual(alert.title, "Rate Limited")
        XCTAssertTrue(alert.message.hasPrefix("Too many requests"))
    }
}
