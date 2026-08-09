//
//  ChatView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/02/2026.
//

import FoundationModels
import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(PubMedToolStore.self) private var pubMedStore
    @Environment(CrossPromoSignal.self) private var crossPromoSignal

    @Binding var configuration: ModelConfiguration

    @State private var session: LanguageModelSession
    @State private var messages: [ChatMessage]
    @State private var input = ""
    @State private var isResponding = false
    @State private var showingSettings = false
    @State private var hasSeeded = false
    @Binding var responseType: ModelResponseType
    @State private var threadId: UUID?

    let title: String
    let seedPrompt: String?

    init(
        title: String,
        seedPrompt: String?,
        session: LanguageModelSession,
        configuration: Binding<ModelConfiguration>,
        responseType: Binding<ModelResponseType>,
        threadId: UUID?,
        initialMessages: [ChatMessage]
    ) {
        self.title = title
        self.seedPrompt = seedPrompt
        self._configuration = configuration
        self._session = State(initialValue: session)
        self._messages = State(initialValue: Self.orderedMessages(from: initialMessages))
        self._responseType = responseType
        self._threadId = State(initialValue: threadId)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.title2)
                .bold()
                .padding(8)
                .padding(.top)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            MessageListView(
                messages: messages,
                isResponding: isResponding
            )

            PromptInputView(
                text: $input,
                placeholder: viewModel.placeholderText,
                isDisabled: isResponding,
                onSubmit: sendMessage
            )
        }
        .onChange(of: configuration.instructions) {
            session = configuredSession()
        }
        .onAppear {
            session = configuredSession()
            seedConversationIfNeeded()
        }
        .onDisappear {
            saveThreadOnDismiss()
        }
    }

    /// Sends the current input as a message and generates a response.
    ///
    /// This method dispatches to the appropriate generation strategy based on the
    /// current `responseType` setting.
    @MainActor
    func sendMessage() {
        guard input.isReallyEmpty == false else { return }
        pubMedStore.reset()
        let prompt = input.trimmed
        messages.append(ChatMessage(content: prompt, isUser: true))
        input = ""

        let resolvedPrompt = resolvedMedicalPrompt(for: prompt)

        if let clarifyingQuestion = MedicalPromptAnalyzer.clarifyingQuestion(for: resolvedPrompt) {
            messages.append(ChatMessage(content: clarifyingQuestion, isUser: false))
            return
        }

        session = compactedSessionFromMessages(excludingLastAssistant: false)

        Task {
            switch responseType {
            case .standard: await generateStandardResponse(for: resolvedPrompt)
            case .streaming: await generateStreamingResponse(for: resolvedPrompt)
            case .human: await generateHumanResponse(for: resolvedPrompt)
            }
        }
    }

    /// Generates a response using the standard (non-streaming) approach.
    ///
    /// The entire response is generated before being displayed. Handles context window
    /// overflow by compacting the session and retrying.
    /// - Parameter prompt: The user's message to respond to.
    @MainActor
    func generateStandardResponse(for prompt: String) async {
        isResponding = true
        defer { isResponding = false }

        let response = await generateResponseWithRecovery(for: prompt)
        if let response {
            messages.append(makeAssistantMessage(from: response))
        } else {
            appendRecoveryFailureMessage()
        }
    }

    /// Generates a response using streaming, updating the UI as tokens arrive.
    ///
    /// Creates an empty message placeholder that updates in real-time as the
    /// response is generated. Handles context window overflow by compacting and retrying.
    /// - Parameter prompt: The user's message to respond to.
    @MainActor
    func generateStreamingResponse(for prompt: String) async {
        isResponding = true
        defer { isResponding = false }

        let messageId = UUID()
        let timestamp = Date()
        var messageIndex: Int?
        var streamedContent = ""

        do {
            let preparedRequest = await prepareModelRequest(for: prompt)
            switch preparedRequest {
            case .assistantResponse(let response):
                messages.append(makeAssistantMessage(from: response, id: messageId, timestamp: timestamp))
                return
            case .prompt(let preparedPrompt):
                for try await partial in session.streamResponse(to: preparedPrompt, options: configuration.generationOptions) {
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
            let response = buildAssistantResponse(from: streamedContent)
            if isRefusalMessage(response.content), let recovered = await recoverAfterFailure(for: prompt) {
                if let messageIndex {
                    messages[messageIndex] = makeAssistantMessage(from: recovered, id: messageId, timestamp: timestamp)
                } else {
                    messages.append(makeAssistantMessage(from: recovered, id: messageId, timestamp: timestamp))
                }
            } else if isRefusalMessage(response.content) {
                let recoveryMessage = ChatMessage(
                    id: messageId,
                    content: recoveryFailureMessage,
                    isUser: false,
                    timestamp: timestamp
                )
                if let messageIndex {
                    messages[messageIndex] = recoveryMessage
                } else {
                    messages.append(recoveryMessage)
                }
            } else {
                let assistantMessage = makeAssistantMessage(from: response, id: messageId, timestamp: timestamp)
                if let messageIndex {
                    messages[messageIndex] = assistantMessage
                } else {
                    messages.append(assistantMessage)
                }
            }
        } catch {
            if let recovered = await recoverAfterFailure(for: prompt) {
                let assistantMessage = makeAssistantMessage(from: recovered, id: messageId, timestamp: timestamp)
                if let messageIndex {
                    messages[messageIndex] = assistantMessage
                } else {
                    messages.append(assistantMessage)
                }
            } else {
                let recoveryMessage = ChatMessage(
                    id: messageId,
                    content: recoveryFailureMessage,
                    isUser: false,
                    timestamp: timestamp
                )
                if let messageIndex {
                    messages[messageIndex] = recoveryMessage
                } else {
                    messages.append(recoveryMessage)
                }
            }
        }
    }

    /// Generates a response with simulated human-like typing delays.
    ///
    /// This mode adds artificial delays to simulate a human typing the response,
    /// creating a more natural conversational feel. The response is generated in the
    /// background while initial "thinking" time passes.
    /// - Parameter prompt: The user's message to respond to.
    @MainActor
    func generateHumanResponse(for prompt: String) async {
        let startTime = ContinuousClock.now

        do {
            try await Task.sleep(for: .seconds(2))
            isResponding = true

            guard let response = await generateResponseWithRecovery(for: prompt) else {
                appendRecoveryFailureMessage()
                isResponding = false
                return
            }
            let simulatedTime = Duration.seconds(1 + Double(response.content.count) * 0.02)

            if ContinuousClock.now - startTime < simulatedTime {
                try await Task.sleep(for: simulatedTime - (.now - startTime))
            }

            messages.append(makeAssistantMessage(from: response))
        } catch {
            appendErrorMessage()
        }

        isResponding = false
    }

    /// Appends a standard error message to the conversation.
    @MainActor
    func appendErrorMessage() {
        messages.append(ChatMessage(content: "Sorry, I couldn't generate a response.", isUser: false))
    }

    @MainActor
    private func appendRecoveryFailureMessage() {
        messages.append(ChatMessage(content: recoveryFailureMessage, isUser: false))
    }

    @MainActor
    private func sanitizedResponse(_ response: String) -> String {
        response
            .split(whereSeparator: \.isNewline)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Sources:") == false }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func generateResponseWithRecovery(for prompt: String) async -> AssistantResponse? {
        do {
            let preparedRequest = await prepareModelRequest(for: prompt)
            switch preparedRequest {
            case .assistantResponse(let response):
                return response
            case .prompt(let preparedPrompt):
                let response = try await session.respond(to: preparedPrompt, options: configuration.generationOptions)
                let assistantResponse = buildAssistantResponse(from: response.content)
                if isRefusalMessage(assistantResponse.content) {
                    return await recoverAfterFailure(for: prompt)
                }
                return assistantResponse
            }
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            return await recoverAfterFailure(for: prompt)
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            return await recoverAfterFailure(for: prompt)
        } catch {
            return nil
        }
    }

    @MainActor
    private func recoverAfterFailure(for prompt: String) async -> AssistantResponse? {
        session = compactedSessionFromMessages(excludingLastAssistant: true)
        do {
            let preparedRequest = await prepareModelRequest(for: prompt)
            switch preparedRequest {
            case .assistantResponse(let response):
                return response
            case .prompt(let preparedPrompt):
                let response = try await session.respond(to: preparedPrompt, options: configuration.generationOptions)
                let assistantResponse = buildAssistantResponse(from: response.content)
                return isRefusalMessage(assistantResponse.content) ? nil : assistantResponse
            }
        } catch {
            return nil
        }
    }

    @MainActor
    private func compactedSessionFromMessages(
        excludingLastAssistant: Bool,
        maxCharacters: Int = 4000
    ) -> LanguageModelSession {
        var entries: [Transcript.Entry] = []

        if configuration.instructions.isReallyEmpty == false {
            let instructionSegment = Transcript.Segment.text(.init(content: configuration.instructions))
            let instructions = Transcript.Instructions(
                segments: [instructionSegment],
                toolDefinitions: []
            )
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
                let prompt = Transcript.Prompt(segments: [segment])
                entries.append(.prompt(prompt))
            } else {
                let response = Transcript.Response(assetIDs: [], segments: [segment])
                entries.append(.response(response))
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

    @MainActor
    private func isRefusalMessage(_ content: String) -> Bool {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Self.refusalPhrases.contains { normalized.localizedStandardContains($0) }
    }

    private var recoveryFailureMessage: String {
        "I couldn't continue with that request. Try rephrasing, shortening the message, or starting a new chat."
    }

    @MainActor
    private func buildAssistantResponse(from content: String) -> AssistantResponse {
        AssistantResponse(
            content: sanitizedResponse(content),
            toolNames: currentToolNames(),
            toolSources: currentToolSources()
        )
    }

    @MainActor
    private func prepareModelRequest(for prompt: String) async -> PreparedModelRequest {
        pubMedStore.reset()

        guard let searchRequest = MedicalPromptAnalyzer.searchRequest(for: prompt) else {
            return .prompt(prompt)
        }

        do {
            let bundle = try await PubMedSearchTool.search(request: searchRequest)
            pubMedStore.record(sources: bundle.sources)
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

    private func configuredSession() -> LanguageModelSession {
        if configuration.instructions.isReallyEmpty {
            return AppLanguageModel.session()
        }
        return AppLanguageModel.session(instructions: configuration.instructions)
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

    @MainActor
    private func currentToolNames() -> [String] {
        pubMedStore.wasUsed ? ["PubMed"] : []
    }

    @MainActor
    private func currentToolSources() -> [ChatMessageSource] {
        pubMedStore.sources.map { source in
            ChatMessageSource(
                title: source.title.replacing("\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines),
                pmid: source.pmid,
                url: source.url
            )
        }
    }

    @MainActor
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

    @MainActor
    private func seedConversationIfNeeded() {
        guard hasSeeded == false, let prompt = seedPrompt, messages.isEmpty else { return }
        hasSeeded = true
        messages.append(ChatMessage(content: prompt, isUser: true))
        Task {
            await generateStreamingResponse(for: prompt)
        }
    }

    @MainActor
    private func saveThreadOnDismiss() {
        guard messages.isEmpty == false else { return }

        var messagesToSave = messages
        if isResponding, let last = messagesToSave.last, last.isUser == false {
            messagesToSave.removeLast()
        }

        guard messagesToSave.isEmpty == false else { return }

        let id = threadId ?? UUID()
        threadId = id
        let fetch = FetchDescriptor<ChatThread>(
            predicate: #Predicate { $0.id == id }
        )
        let existing = (try? modelContext.fetch(fetch))?.first
        if let existing {
            let orderedExisting = Self.orderedMessages(from: existing.messages)
            let orderedNew = Self.orderedMessages(from: messagesToSave)
            let hasNewMessage = orderedNew.count > orderedExisting.count
                || orderedNew.last?.id != orderedExisting.last?.id
            guard hasNewMessage else { return }
            existing.title = title
            existing.messages = orderedNew
            existing.lastUpdated = Date()
        } else {
            let orderedNew = Self.orderedMessages(from: messagesToSave)
            let thread = ChatThread(
                id: id,
                title: title,
                messages: orderedNew,
                creationDate: Date(),
                lastUpdated: Date()
            )
            modelContext.insert(thread)
            crossPromoSignal.bump()
        }
        try? modelContext.save()
    }

    private static func orderedMessages(from messages: [ChatMessage]) -> [ChatMessage] {
        messages.sorted {
            if $0.timestamp != $1.timestamp {
                return $0.timestamp < $1.timestamp
            }
            return $0.id.uuidString < $1.id.uuidString
        }
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

enum MedicalPromptAnalyzer {
    private static let medicalKeywords = Set([
        "adhd", "anxiety", "arthritis", "asthma", "blood", "bp", "cancer", "cholesterol",
        "clinical", "cortisol", "creatine", "depression", "diabetes", "dose", "dosage",
        "drug", "fatigue", "fever", "glucose", "headache", "health", "heart", "hypertension",
        "ibuprofen", "insomnia", "kidney", "liver", "magnesium", "medical", "medication",
        "melatonin", "migraine", "pain", "pharmacology", "pressure", "protein", "renal",
        "sertraline", "sleep", "supplement", "symptom", "therapy", "treatment", "vitamin"
    ])

    private static let populationKeywords = Set([
        "adult", "adults", "aged", "athlete", "athletes", "boy", "boys", "child", "children",
        "elderly", "female", "females", "girl", "girls", "healthy", "healthy-adults", "infant",
        "infants", "male", "males", "men", "older", "patient", "patients", "people", "pregnant",
        "teen", "teenager", "teenagers", "women", "woman"
    ])

    private static let interventionKeywords = Set([
        "acetaminophen", "caffeine", "coffee", "creatine", "drug", "exercise", "ibuprofen",
        "magnesium", "medication", "melatonin", "metformin", "protein", "sertraline",
        "supplement", "therapy", "treatment", "vitamin"
    ])

    private static let genericInterventionKeywords = Set([
        "drug", "medication", "protein", "supplement", "therapy", "treatment", "vitamin"
    ])

    private static let outcomeKeywords = Set([
        "bad", "benefit", "benefits", "cause", "causes", "effective", "effectiveness",
        "harm", "harmful", "help", "helps", "improve", "improves", "improving", "reduce",
        "reduces", "risk", "risks", "safe", "safety", "side", "worse", "worsen"
    ])

    private static let conditionKeywords = Set([
        "adhd", "anxiety", "arthritis", "asthma", "blood", "cancer", "cholesterol", "depression",
        "diabetes", "fatigue", "headache", "hypertension", "insomnia", "kidney", "liver",
        "migraine", "pain", "pressure", "renal", "sleep", "stress"
    ])

    static func clarifyingQuestion(for prompt: String) -> String? {
        let tokens = normalizedTokens(from: prompt)
        guard isMedicalPrompt(tokens: tokens) else { return nil }

        let hasPopulation = tokens.contains(where: populationKeywords.contains)
        let hasIntervention = tokens.contains(where: interventionKeywords.contains)
        let hasOutcome = tokens.contains(where: outcomeKeywords.contains) || prompt.contains("?")
        let hasCondition = tokens.contains(where: conditionKeywords.contains)
        let hasSpecificIntervention = tokens.contains {
            interventionKeywords.contains($0) && genericInterventionKeywords.contains($0) == false
        }
        if hasSpecificIntervention == false && hasCondition == false {
            return "To look up the right PubMed evidence, what specific treatment, supplement, symptom, or condition are you asking about?"
        }

        let populatedDimensions = [hasPopulation, hasIntervention, hasOutcome, hasCondition]
            .filter { $0 }
            .count

        guard populatedDimensions < 2 else { return nil }

        return "To look up the right PubMed evidence, what outcome should I focus on, for example effectiveness, safety, side effects, or risk?"
    }

    static func searchRequest(for prompt: String) -> PubMedSearchRequest? {
        let tokens = normalizedTokens(from: prompt)
        guard isMedicalPrompt(tokens: tokens) else { return nil }

        let normalizedPrompt = prompt.lowercased()
        let intervention = firstMatchingPhrase(in: normalizedPrompt, candidates: interventionPhrases) ?? ""
        let topic = firstMatchingPhrase(in: normalizedPrompt, candidates: conditionPhrases)
            ?? firstMatchingPhrase(in: normalizedPrompt, candidates: symptomPhrases)
            ?? (intervention.isEmpty == false ? intervention : prompt.trimmingCharacters(in: .whitespacesAndNewlines))
        let population = firstMatchingPhrase(in: normalizedPrompt, candidates: populationPhrases) ?? ""
        let outcome = firstMatchingPhrase(in: normalizedPrompt, candidates: outcomePhrases) ?? ""
        let studyPreference: PubMedSearchTool.StudyPreference

        if normalizedPrompt.localizedStandardContains("meta-analysis")
            || normalizedPrompt.localizedStandardContains("systematic review")
            || normalizedPrompt.localizedStandardContains("review") {
            studyPreference = .review
        } else if normalizedPrompt.localizedStandardContains("trial")
            || normalizedPrompt.localizedStandardContains("randomized") {
            studyPreference = .trial
        } else if normalizedPrompt.localizedStandardContains("cohort")
            || normalizedPrompt.localizedStandardContains("observational") {
            studyPreference = .observational
        } else {
            studyPreference = .review
        }

        return PubMedSearchRequest(
            arguments: PubMedSearchTool.Arguments(
                topic: topic,
                population: population.isEmpty ? nil : population,
                interventionOrExposure: intervention.isEmpty ? nil : intervention,
                outcome: outcome.isEmpty ? nil : outcome,
                studyPreference: studyPreference,
                includeAbstracts: true,
                maxResults: 3,
                maxCharacters: 6000
            )
        )
    }

    private static func isMedicalPrompt(tokens: [String]) -> Bool {
        tokens.contains(where: medicalKeywords.contains)
    }

    static func isMedicalPromptText(_ prompt: String) -> Bool {
        isMedicalPrompt(tokens: normalizedTokens(from: prompt))
    }

    static func isClarifyingQuestion(_ text: String) -> Bool {
        text.localizedStandardContains("To look up the right PubMed evidence")
    }

    private static func normalizedTokens(from prompt: String) -> [String] {
        prompt
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
    }

    private static func firstMatchingPhrase(in prompt: String, candidates: [String]) -> String? {
        candidates.first { prompt.localizedStandardContains($0) }
    }

    private static let populationPhrases = [
        "healthy adults", "adults", "children", "older adults", "teenagers", "pregnant women", "patients"
    ]

    private static let interventionPhrases = [
        "magnesium glycinate", "magnesium", "melatonin", "creatine", "coffee", "caffeine",
        "ibuprofen", "acetaminophen", "sertraline", "metformin", "exercise"
    ]

    private static let conditionPhrases = [
        "sleep quality", "kidney function", "kidney safety", "anxiety", "adhd", "insomnia",
        "blood pressure", "cholesterol", "migraine", "depression", "diabetes", "fatigue"
    ]

    private static let symptomPhrases = [
        "sleep", "pain", "headache", "stress", "blood pressure", "kidney"
    ]

    private static let outcomePhrases = [
        "improve sleep", "sleep quality", "kidney safety", "side effects", "safety",
        "effectiveness", "risk", "benefit", "benefits", "harm", "harmful"
    ]
}

#Preview {
    NavigationStack {
        ChatView(
            title: "Preview",
            seedPrompt: nil,
            session: AppLanguageModel.session(),
            configuration: .constant(ModelConfiguration()),
            responseType: .constant(.standard),
            threadId: nil,
            initialMessages: []
        )
    }
    .environment(HomeViewModel())
    .environment(PubMedToolStore.shared)
    .environment(CrossPromoSignal())
    .modelContainer(for: [ChatThread.self, ChatMessage.self], inMemory: true)
}
