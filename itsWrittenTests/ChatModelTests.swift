//
//  ChatModelTests.swift
//  WrittenTests
//
//  Created by Filippo Cilia on 22/02/2026.
//

import XCTest
@testable import itsWritten

final class ChatModelTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let id = UUID(uuidString: "A8A6D8B1-75D6-4F9F-8A2A-2168C1F1E5F1")!
        let creationDate = Date(timeIntervalSince1970: 1_706_000_000)
        let model = ChatModel(
            id: id,
            title: "Test Title",
            prompt: "Test prompt",
            response: "Test response",
            creationDate: creationDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(model)
        let decoded = try decoder.decode(ChatModel.self, from: data)

        XCTAssertEqual(decoded, model)
    }

    func testEqualityConsidersIdentifier() {
        let creationDate = Date(timeIntervalSince1970: 1_706_000_000)
        let modelA = ChatModel(
            id: UUID(uuidString: "3F1E6A7D-2E0A-42F0-8F49-BA0D79B5F8D2")!,
            title: "Title",
            prompt: "Prompt",
            response: "Response",
            creationDate: creationDate
        )
        let modelB = ChatModel(
            id: UUID(uuidString: "B0F7C2D4-5D87-4C3B-9B1C-9B9E35E7A1A4")!,
            title: "Title",
            prompt: "Prompt",
            response: "Response",
            creationDate: creationDate
        )

        XCTAssertNotEqual(modelA, modelB)
    }

    func testChatMessageDefaultsToNoToolMetadata() {
        let message = ChatMessage(content: "Hello", isUser: false)

        XCTAssertTrue(message.toolNames.isEmpty)
        XCTAssertTrue(message.toolSources.isEmpty)
    }

    func testMedicalPromptAnalyzerDefaultsToHumansWhenPopulationIsMissing() {
        let question = MedicalPromptAnalyzer.clarifyingQuestion(for: "Is magnesium good for sleep?")

        XCTAssertNil(question)
    }

    func testMedicalPromptAnalyzerDoesNotInterruptSpecificPrompt() {
        let question = MedicalPromptAnalyzer.clarifyingQuestion(
            for: "Does magnesium glycinate improve sleep in healthy adults?"
        )

        XCTAssertNil(question)
    }

    func testPubMedQueryIncludesStructuredFieldsAndFilters() {
        let request = PubMedSearchRequest(
            arguments: PubMedSearchTool.Arguments(
                topic: "sleep quality",
                population: "healthy adults",
                interventionOrExposure: "magnesium glycinate",
                outcome: "improve sleep",
                studyPreference: .trial,
                includeAbstracts: true,
                maxResults: 3,
                maxCharacters: 4000
            )
        )

        let query = PubMedSearchTool.query(for: request)

        XCTAssertEqual(
            query,
            "(sleep quality) AND (magnesium glycinate) AND (improve sleep) AND (healthy adults) AND humans[mh] AND (randomized controlled trial[pt] OR clinical trial[pt])"
        )
    }

    func testPubMedRerankingPrefersAdultHumanReviewForBroadQuestion() {
        let request = PubMedSearchRequest(
            arguments: PubMedSearchTool.Arguments(
                topic: "sleep quality",
                population: "healthy adults",
                interventionOrExposure: "magnesium glycinate",
                outcome: "improve sleep",
                studyPreference: .review,
                includeAbstracts: true,
                maxResults: 1,
                maxCharacters: 4000
            )
        )

        let adultReview = PubMedArticle(
            pmid: "1",
            title: "Magnesium glycinate and sleep quality in healthy adults",
            journal: "Sleep Medicine Reviews",
            year: "2024",
            abstractSections: ["Systematic review of human studies on sleep quality in adults."],
            publicationTypes: ["Systematic Review"],
            speciesTags: ["Humans"]
        )
        let pediatricAnimalStudy = PubMedArticle(
            pmid: "2",
            title: "Magnesium and sleep in adolescent mice",
            journal: "Experimental Sleep",
            year: "2025",
            abstractSections: ["Animal study in adolescent mice."],
            publicationTypes: ["Journal Article"],
            speciesTags: ["Animals"]
        )

        let ranked = PubMedSearchTool.rankedArticles(from: [pediatricAnimalStudy, adultReview], for: request)

        XCTAssertEqual(ranked.first?.pmid, "1")
    }

    func testMedicalPromptAnalyzerStillAsksWhenTopicIsTooUnspecific() {
        let question = MedicalPromptAnalyzer.clarifyingQuestion(for: "Is this supplement good?")

        XCTAssertEqual(
            question,
            "To look up the right PubMed evidence, what specific treatment, supplement, symptom, or condition are you asking about?"
        )
    }
}
