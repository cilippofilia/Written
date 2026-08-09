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

    /// Bumped by `reset()` and `resume(thread:config:)`. Captured by in-flight
    /// generation/title work so a stale Task from a superseded conversation can detect
    /// it no longer owns the current state and stop before mutating it.
    private(set) var generation = 0

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
        guard mode == .composing else { return }
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
        generation += 1
        messages = Self.orderedMessages(from: thread.messages)
        title = thread.title
        threadId = thread.id
        session = buildSession(from: messages, config: config)
        isResponding = false
        mode = .chatting
    }

    /// Clears the current conversation and returns to the composer.
    func reset(config: ModelConfiguration) {
        generation += 1
        messages = []
        title = "New Conversation"
        threadId = nil
        isResponding = false
        session = configuredSession(config: config)
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

// MARK: - Sending Messages

extension ConversationViewModel {
    /// Starts a brand-new conversation from the composer's first message. Switches to
    /// chat mode immediately — the caller does not wait on this before showing the
    /// chat surface.
    func startConversation(with prompt: String, config: ModelConfiguration, responseType: ModelResponseType) {
        mode = .chatting
        session = configuredSession(config: config)
        send(prompt, config: config, responseType: responseType)
    }

    /// Sends a follow-up message within the current conversation.
    func sendMessage(_ prompt: String, config: ModelConfiguration, responseType: ModelResponseType) {
        send(prompt, config: config, responseType: responseType)
    }

    /// Generates a short title in the background and applies it once ready. Failures
    /// are swallowed on purpose: this runs after the conversation is already visible,
    /// so an error here should not interrupt the user — it just leaves the
    /// "New Conversation" placeholder.
    func generateAndSetTitle(from prompt: String) async {
        let myGeneration = generation
        let instructions = """
        Summarize the prompt into a short title of 5 to 8 words.
        DO NOT use tools, lists, markdown, numbering, or quotes.
        Return only the title text.
        """
        let titleSession = AppLanguageModel.sessionWithoutTools(instructions: instructions)

        guard let generated = try? await lastStreamedContent(from: titleSession, prompt: prompt) else { return }
        guard myGeneration == generation else { return }

        let normalized = generated
            .replacing("\n", with: " ")
            .replacing("#", with: "")
            .replacing("-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let words = normalized.split(whereSeparator: \.isWhitespace)
        let clipped = words.prefix(8).joined(separator: " ")
        guard clipped.isEmpty == false else { return }

        title = clipped
        persistCurrentTurn()
    }

    private func lastStreamedContent(from session: LanguageModelSession, prompt: String) async throws -> String {
        var result = ""
        for try await partial in session.streamResponse(to: prompt) {
            result = partial.content
        }
        return result
    }

    private func send(_ prompt: String, config: ModelConfiguration, responseType: ModelResponseType) {
        guard prompt.isReallyEmpty == false else { return }
        pubMedStore?.reset()
        let trimmedPrompt = prompt.trimmed
        append(ChatMessage(content: trimmedPrompt, isUser: true))

        let resolvedPrompt = resolvedMedicalPrompt(for: trimmedPrompt)

        if let clarifyingQuestion = MedicalPromptAnalyzer.clarifyingQuestion(for: resolvedPrompt) {
            append(ChatMessage(content: clarifyingQuestion, isUser: false))
            return
        }

        session = compactedSessionFromMessages(config: config, excludingLastAssistant: false)

        let sendGeneration = generation
        Task {
            switch responseType {
            case .standard: await generateStandardResponse(for: resolvedPrompt, config: config, generation: sendGeneration)
            case .streaming: await generateStreamingResponse(for: resolvedPrompt, config: config, generation: sendGeneration)
            case .human: await generateHumanResponse(for: resolvedPrompt, config: config, generation: sendGeneration)
            }
        }
    }

    /// Generates a response using the standard (non-streaming) approach. Handles
    /// context window overflow by compacting the session and retrying.
    private func generateStandardResponse(for prompt: String, config: ModelConfiguration, generation: Int) async {
        guard generation == self.generation else { return }
        isResponding = true
        defer { if generation == self.generation { isResponding = false } }

        let response = await generateResponseWithRecovery(for: prompt, config: config)
        guard generation == self.generation else { return }
        if let response {
            append(makeAssistantMessage(from: response))
        } else {
            appendRecoveryFailureMessage()
        }
    }

    /// Generates a response using streaming, updating the UI as tokens arrive. Handles
    /// context window overflow by compacting and retrying.
    private func generateStreamingResponse(for prompt: String, config: ModelConfiguration, generation: Int) async {
        guard generation == self.generation else { return }
        isResponding = true
        defer { if generation == self.generation { isResponding = false } }

        let messageId = UUID()
        let timestamp = Date()
        var messageIndex: Int?
        var streamedContent = ""

        do {
            let preparedRequest = await prepareModelRequest(for: prompt)
            guard generation == self.generation else { return }
            switch preparedRequest {
            case .assistantResponse(let response):
                append(makeAssistantMessage(from: response, id: messageId, timestamp: timestamp))
                return
            case .prompt(let preparedPrompt):
                for try await partial in session.streamResponse(to: preparedPrompt, options: config.generationOptions) {
                    guard generation == self.generation else { return }
                    streamedContent = partial.content

                    withAnimation(.default) {
                        if let messageIndex {
                            messages[messageIndex] = ChatMessage(
                                id: messageId,
                                content: partial.content,
                                isUser: false,
                                timestamp: timestamp
                            )
                        } else {
                            messages.append(
                                ChatMessage(
                                    id: messageId,
                                    content: partial.content,
                                    isUser: false,
                                    timestamp: timestamp
                                )
                            )
                            messageIndex = messages.endIndex - 1
                        }
                    }
                }
            }
            guard generation == self.generation else { return }
            let response = buildAssistantResponse(from: streamedContent)
            if isRefusalMessage(response.content), let recovered = await recoverAfterFailure(for: prompt, config: config) {
                guard generation == self.generation else { return }
                replaceStreamedMessage(
                    at: &messageIndex,
                    with: makeAssistantMessage(from: recovered, id: messageId, timestamp: timestamp)
                )
            } else if isRefusalMessage(response.content) {
                guard generation == self.generation else { return }
                replaceStreamedMessage(
                    at: &messageIndex,
                    with: ChatMessage(id: messageId, content: recoveryFailureMessage, isUser: false, timestamp: timestamp)
                )
            } else {
                replaceStreamedMessage(
                    at: &messageIndex,
                    with: makeAssistantMessage(from: response, id: messageId, timestamp: timestamp)
                )
            }
        } catch {
            guard generation == self.generation else { return }
            if let recovered = await recoverAfterFailure(for: prompt, config: config) {
                guard generation == self.generation else { return }
                replaceStreamedMessage(
                    at: &messageIndex,
                    with: makeAssistantMessage(from: recovered, id: messageId, timestamp: timestamp)
                )
            } else {
                guard generation == self.generation else { return }
                replaceStreamedMessage(
                    at: &messageIndex,
                    with: ChatMessage(id: messageId, content: recoveryFailureMessage, isUser: false, timestamp: timestamp)
                )
            }
        }
    }

    private func replaceStreamedMessage(at messageIndex: inout Int?, with message: ChatMessage) {
        if let messageIndex {
            messages[messageIndex] = message
        } else {
            messages.append(message)
        }
        persistCurrentTurn()
    }

    /// Generates a response with simulated human-like typing delays.
    private func generateHumanResponse(for prompt: String, config: ModelConfiguration, generation: Int) async {
        guard generation == self.generation else { return }
        let startTime = ContinuousClock.now

        do {
            try await Task.sleep(for: .seconds(2))
            guard generation == self.generation else { return }
            isResponding = true

            guard let response = await generateResponseWithRecovery(for: prompt, config: config) else {
                guard generation == self.generation else { return }
                appendRecoveryFailureMessage()
                isResponding = false
                return
            }
            guard generation == self.generation else { return }
            let simulatedTime = Duration.seconds(1 + Double(response.content.count) * 0.02)

            if ContinuousClock.now - startTime < simulatedTime {
                try await Task.sleep(for: simulatedTime - (.now - startTime))
            }

            guard generation == self.generation else { return }
            append(makeAssistantMessage(from: response))
        } catch {
            guard generation == self.generation else { return }
            appendErrorMessage()
        }

        if generation == self.generation {
            isResponding = false
        }
    }

    private func appendErrorMessage() {
        append(ChatMessage(content: "Sorry, I couldn't generate a response.", isUser: false))
    }

    private func appendRecoveryFailureMessage() {
        append(ChatMessage(content: recoveryFailureMessage, isUser: false))
    }

    private func sanitizedResponse(_ response: String) -> String {
        response
            .split(whereSeparator: \.isNewline)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Sources:") == false }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generateResponseWithRecovery(for prompt: String, config: ModelConfiguration) async -> AssistantResponse? {
        do {
            let preparedRequest = await prepareModelRequest(for: prompt)
            switch preparedRequest {
            case .assistantResponse(let response):
                return response
            case .prompt(let preparedPrompt):
                let response = try await session.respond(to: preparedPrompt, options: config.generationOptions)
                let assistantResponse = buildAssistantResponse(from: response.content)
                if isRefusalMessage(assistantResponse.content) {
                    return await recoverAfterFailure(for: prompt, config: config)
                }
                return assistantResponse
            }
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            return await recoverAfterFailure(for: prompt, config: config)
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            return await recoverAfterFailure(for: prompt, config: config)
        } catch {
            return nil
        }
    }

    private func recoverAfterFailure(for prompt: String, config: ModelConfiguration) async -> AssistantResponse? {
        session = compactedSessionFromMessages(config: config, excludingLastAssistant: true)
        do {
            let preparedRequest = await prepareModelRequest(for: prompt)
            switch preparedRequest {
            case .assistantResponse(let response):
                return response
            case .prompt(let preparedPrompt):
                let response = try await session.respond(to: preparedPrompt, options: config.generationOptions)
                let assistantResponse = buildAssistantResponse(from: response.content)
                return isRefusalMessage(assistantResponse.content) ? nil : assistantResponse
            }
        } catch {
            return nil
        }
    }

    private func compactedSessionFromMessages(
        config: ModelConfiguration,
        excludingLastAssistant: Bool,
        maxCharacters: Int = 4000
    ) -> LanguageModelSession {
        var entries: [Transcript.Entry] = []

        if config.instructions.isReallyEmpty == false {
            let instructionSegment = Transcript.Segment.text(.init(content: config.instructions))
            let instructions = Transcript.Instructions(segments: [instructionSegment], toolDefinitions: [])
            entries.append(.instructions(instructions))
        }

        var ordered = Self.orderedMessages(from: messages)
        if excludingLastAssistant, let last = ordered.last, last.isUser == false {
            ordered.removeLast()
        }

        for message in ordered {
            if message.isUser == false, isRefusalMessage(message.content) {
                continue
            }
            let segment = Transcript.Segment.text(.init(content: message.content))
            if message.isUser {
                entries.append(.prompt(Transcript.Prompt(segments: [segment])))
            } else {
                entries.append(.response(Transcript.Response(assetIDs: [], segments: [segment])))
            }
        }

        guard let first = entries.first else {
            return session
        }

        var selected = [first]
        var totalInstructionLength = String(describing: first).count
        var recentEntries: [Transcript.Entry] = []

        for entry in entries.dropFirst().reversed() {
            let entryEstimateLength = String(describing: entry).count
            guard totalInstructionLength + entryEstimateLength <= maxCharacters else { break }
            recentEntries.insert(entry, at: 0)
            totalInstructionLength += entryEstimateLength
        }

        selected.append(contentsOf: recentEntries)
        return AppLanguageModel.session(transcript: Transcript(entries: selected))
    }

    /// Pure string matching against known refusal phrasing — no FoundationModels call
    /// involved, kept `internal` (not `private`) so it's directly unit-testable.
    func isRefusalMessage(_ content: String) -> Bool {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Self.refusalPhrases.contains { normalized.localizedStandardContains($0) }
    }

    private var recoveryFailureMessage: String {
        "I couldn't continue with that request. Try rephrasing, shortening the message, or starting a new chat."
    }

    private func buildAssistantResponse(from content: String) -> AssistantResponse {
        AssistantResponse(
            content: sanitizedResponse(content),
            toolNames: currentToolNames(),
            toolSources: currentToolSources()
        )
    }

    private func prepareModelRequest(for prompt: String) async -> PreparedModelRequest {
        pubMedStore?.reset()

        guard let searchRequest = MedicalPromptAnalyzer.searchRequest(for: prompt) else {
            return .prompt(prompt)
        }

        do {
            let bundle = try await PubMedSearchTool.search(request: searchRequest)
            pubMedStore?.record(sources: bundle.sources)
            return .prompt(synthesisPrompt(for: prompt, bundle: bundle))
        } catch PubMedSearchError.noResults {
            return .assistantResponse(
                AssistantResponse(
                    content: "I couldn't find relevant human PubMed evidence for that question. Try being more specific about the condition, treatment, or outcome you want to check.",
                    toolNames: [],
                    toolSources: []
                )
            )
        } catch PubMedSearchError.rateLimited {
            return .assistantResponse(
                AssistantResponse(
                    content: "PubMed is temporarily rate-limiting requests, so I couldn't verify that with research right now. Try again in a moment.",
                    toolNames: [],
                    toolSources: []
                )
            )
        } catch {
            return .assistantResponse(
                AssistantResponse(
                    content: "I couldn't retrieve PubMed evidence right now, so I don't want to guess. Try again in a moment or rephrase the question more specifically.",
                    toolNames: [],
                    toolSources: []
                )
            )
        }
    }

    private func synthesisPrompt(for prompt: String, bundle: PubMedEvidenceBundle) -> String {
        """
        User question:
        \(prompt)

        PubMed evidence:
        \(PubMedSearchTool.evidenceSummary(for: bundle))

        Instructions:
        - Answer the user's question using only the evidence above for factual medical claims.
        - If the evidence is limited, mixed, indirect, or does not fully answer the question, say so plainly.
        - Do not mention search queries or URLs in the body of the answer.
        """
    }

    private func resolvedMedicalPrompt(for prompt: String) -> String {
        guard MedicalPromptAnalyzer.isMedicalPromptText(prompt) == false else {
            return prompt
        }
        guard messages.count >= 3 else { return prompt }

        let assistantIndex = messages.count - 2
        let assistantMessage = messages[assistantIndex]
        guard assistantMessage.isUser == false, MedicalPromptAnalyzer.isClarifyingQuestion(assistantMessage.content) else {
            return prompt
        }

        for index in stride(from: assistantIndex - 1, through: 0, by: -1) {
            let candidate = messages[index]
            guard candidate.isUser else { continue }
            if MedicalPromptAnalyzer.isMedicalPromptText(candidate.content) {
                return "\(candidate.content) \(prompt)"
            }
        }

        return prompt
    }

    private func currentToolNames() -> [String] {
        (pubMedStore?.wasUsed ?? false) ? ["PubMed"] : []
    }

    private func currentToolSources() -> [ChatMessageSource] {
        (pubMedStore?.sources ?? []).map { source in
            ChatMessageSource(
                title: source.title.replacing("\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines),
                pmid: source.pmid,
                url: source.url
            )
        }
    }

    private func makeAssistantMessage(
        from response: AssistantResponse,
        id: UUID = UUID(),
        timestamp: Date = .now
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            content: response.content,
            isUser: false,
            timestamp: timestamp,
            toolNames: response.toolNames,
            toolSources: response.toolSources
        )
    }

    /// Appends a message to the conversation and persists it immediately. `internal`
    /// (not `private`) so autosave behavior can be driven directly from tests without
    /// requiring a live FoundationModels call.
    func append(_ message: ChatMessage) {
        messages.append(message)
        persistCurrentTurn()
    }

    /// Inserts the `ChatThread` on the first message of a new conversation, or updates
    /// the existing one on every message after that. Called after every `append` and
    /// after every finalized streamed message, so the conversation is durable as it
    /// happens rather than only when the screen is dismissed.
    func persistCurrentTurn() {
        guard let modelContext, messages.isEmpty == false else { return }

        if let threadId {
            let fetch = FetchDescriptor<ChatThread>(predicate: #Predicate { $0.id == threadId })
            guard let existing = (try? modelContext.fetch(fetch))?.first else { return }
            existing.title = title
            existing.messages = Self.orderedMessages(from: messages)
            existing.lastUpdated = .now
        } else {
            let id = UUID()
            threadId = id
            let thread = ChatThread(
                id: id,
                title: title,
                messages: Self.orderedMessages(from: messages),
                creationDate: .now,
                lastUpdated: .now
            )
            modelContext.insert(thread)
            crossPromoSignal?.bump()
        }

        try? modelContext.save()
    }

    private static let refusalPhrases = [
        "i can't help",
        "i cannot help",
        "i can't assist",
        "i cannot assist",
        "i'm sorry, but i can't",
        "i'm sorry, but i cannot",
        "i'm sorry, i can't",
        "i'm sorry, i cannot",
        "i'm sorry, but i can't assist",
        "i'm sorry, but i cannot assist",
        "i can't provide that",
        "i cannot provide that",
        "i can't help with that",
        "i cannot help with that"
    ]
}

private struct AssistantResponse {
    let content: String
    let toolNames: [String]
    let toolSources: [ChatMessageSource]
}

private enum PreparedModelRequest {
    case prompt(String)
    case assistantResponse(AssistantResponse)
}
