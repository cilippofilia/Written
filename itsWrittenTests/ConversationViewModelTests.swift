//
//  ConversationViewModelTests.swift
//  itsWrittenTests
//
//  Created by Filippo Cilia on 09/08/2026.
//

import FoundationModels
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

        viewModel.reset()

        XCTAssertEqual(viewModel.mode, .composing)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertNil(viewModel.threadId)
        XCTAssertEqual(viewModel.title, "New Conversation")
    }
}
