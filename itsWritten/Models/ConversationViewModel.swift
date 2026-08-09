//
//  ConversationViewModel.swift
//  itsWritten
//
//  Created by Filippo Cilia on 09/08/2026.
//

import FoundationModels
import SwiftData
import SwiftUI

/// Owns the state and behavior for a single conversation surface: the composer before
/// a chat starts, and the message thread once it has. Replaces the previous split
/// between `HomeContentView`'s composer state and the sheet-presented `ChatView`'s
/// own state, so both live in one place and the chat can be shown inline instead of
/// modally.
@MainActor
@Observable
final class ConversationViewModel {
    enum Mode: Equatable {
        case composing
        case chatting
    }

    private(set) var mode: Mode = .composing
    private(set) var messages: [ChatMessage] = []
    var title = "New Conversation"
    private(set) var threadId: UUID?
    private(set) var session = AppLanguageModel.session()
    private(set) var isResponding = false

    private var modelContext: ModelContext?
    private var pubMedStore: PubMedToolStore?
    private var crossPromoSignal: CrossPromoSignal?

    /// Injects the runtime dependencies this view model needs. Must be called once,
    /// from `HomeView.onAppear`, before `startConversation`/`sendMessage`/`resume` are
    /// used — SwiftUI environment values aren't available at `@State` initializer time,
    /// so they can't be passed into `init`.
    func configure(
        modelContext: ModelContext,
        pubMedStore: PubMedToolStore,
        crossPromoSignal: CrossPromoSignal
    ) {
        self.modelContext = modelContext
        self.pubMedStore = pubMedStore
        self.crossPromoSignal = crossPromoSignal
    }

    /// Builds a fresh idle session from `config` and prewarms it. Call once, from
    /// `HomeView.onAppear`.
    func prewarmIdleSession(config: ModelConfiguration) {
        session = configuredSession(config: config)
        // `prewarm` is a synchronous, non-async FoundationModels call that can block
        // on the on-device model backend. Apple's own docs note it "does not guarantee
        // the system loads your assets immediately", so it's safe to defer off the
        // synchronous caller's path — otherwise it can stall the MainActor run loop
        // long enough to starve other `.task`s in the view hierarchy (e.g. the
        // cross-promo ad fetch never gets a chance to start).
        let instructions = config.instructions
        Task { @MainActor in
            session.prewarm(promptPrefix: .init(instructions))
        }
    }

    /// Rebuilds the session from `config` without prewarming. Only meaningful while
    /// chatting — matches the previous behavior where only the active `ChatView`
    /// rebuilt its session in response to instruction changes.
    func rebuildSession(config: ModelConfiguration) {
        guard mode == .chatting else { return }
        session = configuredSession(config: config)
    }

    /// Loads a previously saved thread into the conversation and switches to chat mode.
    func resume(thread: ChatThread, config: ModelConfiguration) {
        messages = Self.orderedMessages(from: thread.messages)
        title = thread.title
        threadId = thread.id
        session = buildSession(from: messages, config: config)
        mode = .chatting
    }

    /// Clears the current conversation and returns to the composer.
    func reset() {
        messages = []
        title = "New Conversation"
        threadId = nil
        isResponding = false
        mode = .composing
    }

    private func configuredSession(config: ModelConfiguration) -> LanguageModelSession {
        if config.instructions.isReallyEmpty {
            return AppLanguageModel.session()
        }
        return AppLanguageModel.session(instructions: config.instructions)
    }

    private func buildSession(from messages: [ChatMessage], config: ModelConfiguration) -> LanguageModelSession {
        var entries: [Transcript.Entry] = []

        if config.instructions.isReallyEmpty == false {
            let instructionSegment = Transcript.Segment.text(.init(content: config.instructions))
            let instructions = Transcript.Instructions(segments: [instructionSegment], toolDefinitions: [])
            entries.append(.instructions(instructions))
        }

        for message in messages {
            let segment = Transcript.Segment.text(.init(content: message.content))
            if message.isUser {
                entries.append(.prompt(Transcript.Prompt(segments: [segment])))
            } else {
                entries.append(.response(Transcript.Response(assetIDs: [], segments: [segment])))
            }
        }

        return AppLanguageModel.session(transcript: Transcript(entries: entries))
    }

    static func orderedMessages(from messages: [ChatMessage]) -> [ChatMessage] {
        messages.sorted {
            if $0.timestamp != $1.timestamp {
                return $0.timestamp < $1.timestamp
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
