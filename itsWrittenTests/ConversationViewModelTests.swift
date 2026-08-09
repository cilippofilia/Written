//
//  ConversationViewModelTests.swift
//  itsWrittenTests
//
//  Created by Filippo Cilia on 09/08/2026.
//

import FoundationModels
import SwiftData
import XCTest
@testable import itsWritten

@MainActor
final class ConversationViewModelTests: XCTestCase {
    func testInitialStateIsComposing() {
        let viewModel = ConversationViewModel()

        XCTAssertEqual(viewModel.mode, .composing)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertNil(viewModel.threadId)
        XCTAssertEqual(viewModel.title, "New Conversation")
        XCTAssertFalse(viewModel.isResponding)
    }

    func testResumeLoadsThreadOrderedByTimestampAndSwitchesToChatting() {
        let viewModel = ConversationViewModel()
        let older = ChatMessage(content: "Hi", isUser: true, timestamp: Date(timeIntervalSince1970: 100))
        let newer = ChatMessage(content: "Hello!", isUser: false, timestamp: Date(timeIntervalSince1970: 200))
        let thread = ChatThread(title: "Greeting", messages: [newer, older])

        viewModel.resume(thread: thread, config: ModelConfiguration())

        XCTAssertEqual(viewModel.mode, .chatting)
        XCTAssertEqual(viewModel.title, "Greeting")
        XCTAssertEqual(viewModel.threadId, thread.id)
        XCTAssertEqual(viewModel.messages.map(\.content), ["Hi", "Hello!"])
    }

    func testResetReturnsToComposingWithClearedState() {
        let viewModel = ConversationViewModel()
        let thread = ChatThread(title: "Greeting", messages: [ChatMessage(content: "Hi", isUser: true)])
        viewModel.resume(thread: thread, config: ModelConfiguration())

        viewModel.reset(config: ModelConfiguration())

        XCTAssertEqual(viewModel.mode, .composing)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertNil(viewModel.threadId)
        XCTAssertEqual(viewModel.title, "New Conversation")
    }

    func testIsRefusalMessageDetectsKnownRefusalPhrases() {
        let viewModel = ConversationViewModel()

        XCTAssertTrue(viewModel.isRefusalMessage("I'm sorry, but I can't help with that request."))
        XCTAssertFalse(viewModel.isRefusalMessage("Here's a summary of the evidence you asked about."))
    }

    func testAppendInsertsNewThreadThenUpdatesOnSubsequentAppend() throws {
        let schema = Schema([ChatThread.self, ChatMessage.self])
        let configuration = SwiftData.ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let crossPromoSignal = CrossPromoSignal()

        let viewModel = ConversationViewModel()
        viewModel.configure(modelContext: context, pubMedStore: PubMedToolStore(), crossPromoSignal: crossPromoSignal)
        viewModel.title = "Morning Pages"

        viewModel.append(ChatMessage(content: "Hi", isUser: true))

        var fetched = try context.fetch(FetchDescriptor<ChatThread>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.messages.count, 1)
        XCTAssertEqual(fetched.first?.title, "Morning Pages")
        XCTAssertEqual(crossPromoSignal.count, 1)
        XCTAssertEqual(viewModel.threadId, fetched.first?.id)

        viewModel.append(ChatMessage(content: "Hello!", isUser: false))

        fetched = try context.fetch(FetchDescriptor<ChatThread>())
        XCTAssertEqual(fetched.count, 1, "a follow-up append should update the existing thread, not insert a second one")
        XCTAssertEqual(fetched.first?.messages.count, 2)
        XCTAssertEqual(crossPromoSignal.count, 1, "crossPromoSignal should only bump once, when the thread is first created")
    }

    func testResetThenAppendCreatesASeparateNewThread() throws {
        let schema = Schema([ChatThread.self, ChatMessage.self])
        let configuration = SwiftData.ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let viewModel = ConversationViewModel()
        viewModel.configure(modelContext: context, pubMedStore: PubMedToolStore(), crossPromoSignal: CrossPromoSignal())
        viewModel.title = "First Thread"
        viewModel.append(ChatMessage(content: "Hi", isUser: true))

        viewModel.reset(config: ModelConfiguration())
        viewModel.title = "Second Thread"
        viewModel.append(ChatMessage(content: "Hello again", isUser: true))

        let fetched = try context.fetch(FetchDescriptor<ChatThread>())
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(Set(fetched.map(\.title)), Set(["First Thread", "Second Thread"]))
    }

    func testResetIncrementsGenerationRebuildsSessionAndClearsIsResponding() {
        let viewModel = ConversationViewModel()
        let thread = ChatThread(title: "Greeting", messages: [ChatMessage(content: "Hi", isUser: true)])
        viewModel.resume(thread: thread, config: ModelConfiguration())
        let generationAfterResume = viewModel.generation
        let sessionAfterResume = viewModel.session

        viewModel.reset(config: ModelConfiguration())

        XCTAssertEqual(viewModel.generation, generationAfterResume + 1)
        XCTAssertFalse(viewModel.isResponding)
        XCTAssertFalse(viewModel.session === sessionAfterResume, "reset should rebuild the session, not reuse the resumed thread's session")
    }

    func testResumeIncrementsGenerationAndClearsIsResponding() {
        let viewModel = ConversationViewModel()
        let generationBefore = viewModel.generation
        let thread = ChatThread(title: "Greeting", messages: [ChatMessage(content: "Hi", isUser: true)])

        viewModel.resume(thread: thread, config: ModelConfiguration())

        XCTAssertEqual(viewModel.generation, generationBefore + 1)
        XCTAssertFalse(viewModel.isResponding)
    }

    func testPersistCurrentTurnDoesNothingWithEmptyMessages() throws {
        let schema = Schema([ChatThread.self, ChatMessage.self])
        let configuration = SwiftData.ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let viewModel = ConversationViewModel()
        viewModel.configure(modelContext: context, pubMedStore: PubMedToolStore(), crossPromoSignal: CrossPromoSignal())
        viewModel.title = "Stale Title"

        viewModel.persistCurrentTurn()

        let fetched = try context.fetch(FetchDescriptor<ChatThread>())
        XCTAssertTrue(fetched.isEmpty, "persisting with no messages should not create a thread")
    }
}
