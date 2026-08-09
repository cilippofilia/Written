# Inline Chat Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the `MessageListView` autoscroll bug and replace the sheet-based chat presentation with a single inline screen, per `docs/superpowers/specs/2026-08-09-inline-chat-design.md`.

**Architecture:** A new `ConversationViewModel` (`@MainActor @Observable`) owned by `HomeView` absorbs the message-send/streaming/session/autosave logic currently living on the `ChatView` struct. `HomeContentView` becomes a mode-switcher (`.composing` / `.chatting`) between the extracted `ComposingView` and a new `ChatConversationView`, both reading the shared view model from the environment. `ChatHistoryView` resumes threads into that same shared view model instead of presenting its own sheet. `MessageListView`'s scroll tracking is separately rewritten onto `ScrollPosition(edge:)` + `onScrollGeometryChange`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, FoundationModels, XCTest (existing test target: `itsWrittenTests`).

## Global Constraints

- Target iOS 26.0+ / macOS 26.0+, Swift 6.0+, modern Swift concurrency throughout.
- `@Observable` classes are marked `@MainActor`.
- No `ObservableObject`; no old-style GCD; no `.onChange()` 1-parameter variant.
- Prefer Swift-native/modern Foundation APIs (`.replacing`, `.localizedStandardContains`, etc.) — already followed by the code being ported; preserve as-is.
- No third-party frameworks may be introduced without asking first (none needed for this plan).
- View logic belongs in view models so it can be unit tested (this is a primary driver of this refactor).
- Break distinct types into their own files rather than bundling multiple types in one file.
- Avoid `AnyView`; avoid hard-coded padding/spacing beyond what's already in the code being ported.
- This work happens on a dedicated feature branch (`feature/inline-chat-refactor`), never on `main`. Per-task commits on that branch are expected — the review/ledger workflow depends on them — but nothing gets pushed to any remote, and no branch other than this feature branch is touched, without the user's explicit go-ahead.
- Run SwiftLint (if configured) with no errors before any commit.

---

### Task 1: Fix `MessageListView` autoscroll (Track 1 — independent)

**Files:**
- Modify: `itsWritten/Views/Chat/MessageListView.swift`

**Interfaces:**
- Consumes: `ChatMessage` (existing, `Models/ChatModel.swift`), `MessageBubble`, `TypingIndicatorView` (existing, unchanged).
- Produces: `MessageListView(messages: [ChatMessage], isResponding: Bool)` — same public init as today, no callers need to change.

This task is self-contained and ships independently of everything else in this plan. The bug: `ScrollViewReader.scrollTo()` (imperative) and `.scrollPosition(id:)` (a two-way binding SwiftUI also writes to as the user scrolls) fight each other, and the exact-id match used for `isAtBottom` can flip to `false` mid-stream and never recover. Fix: replace both with `ScrollPosition(edge: .bottom)` (iOS 18+, purpose-built for "pinned to bottom unless the user scrolled away") and `.onScrollGeometryChange` for real geometry-based bottom-proximity detection.

- [ ] **Step 1: Replace the file's scroll implementation**

```swift
//
//  MessageListView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

struct MessageListView: View {
    let messages: [ChatMessage]
    let isResponding: Bool

    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var isAtBottom = true

    private let typingIndicatorID = "typing-indicator"
    private let bottomProximityThreshold: CGFloat = 60

    private var showsTypingIndicator: Bool {
        guard isResponding else { return false }
        guard let lastMessage = messages.last else { return true }
        return lastMessage.isUser || lastMessage.content.isReallyEmpty
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                        .id(message.id)
                }
                if showsTypingIndicator {
                    TypingIndicatorView()
                        .id(typingIndicatorID)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            let distanceFromBottom = geometry.contentSize.height
                - geometry.contentOffset.y
                - geometry.containerSize.height
            return distanceFromBottom <= bottomProximityThreshold
        } action: { _, newValue in
            isAtBottom = newValue
        }
        .onChange(of: messages.count) {
            scrollToBottomIfNeeded()
        }
        .onChange(of: messages.last?.content) {
            scrollToBottomIfNeeded()
        }
        .onChange(of: isResponding) {
            scrollToBottomIfNeeded()
        }
    }

    /// Scrolls to the latest content, unless the user has scrolled away from the
    /// bottom to read earlier messages.
    private func scrollToBottomIfNeeded() {
        guard isAtBottom else { return }
        withAnimation(.default) {
            scrollPosition.scrollTo(edge: .bottom)
        }
    }
}

#Preview {
    MessageListView(messages: [], isResponding: false)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'generic/platform=iOS Simulator'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manually verify the fix in the Simulator**

There's no UI-test infrastructure in this project (no `ViewInspector`, no XCUITest target) and adding one is out of scope, so this is a manual check, using the `run` skill or `xcodebuild` + `xcrun simctl`:
1. Launch the app, start a new chat, send 4–5 messages back to back (streaming response type). Confirm the view keeps auto-scrolling to the latest content through all of them (this is the reported bug — it used to stop working after a few messages).
2. While a response is streaming, scroll up manually. Confirm autoscroll pauses (new content doesn't yank you back down).
3. Scroll back down to the bottom. Confirm autoscroll resumes for the next message.
4. Open a previously saved thread with several messages from Chat History (still sheet-based until later tasks in this plan land) and confirm it opens already scrolled to the bottom, not the top.

---

### Task 2: Extract `MedicalPromptAnalyzer` into its own file

**Files:**
- Create: `itsWritten/Models/Helpers/MedicalPromptAnalyzer.swift`
- Modify: `itsWritten/Views/Chat/ChatView.swift:604-753` (remove the moved enum)

**Interfaces:**
- Produces: `enum MedicalPromptAnalyzer` with its existing static API (`clarifyingQuestion(for:)`, `searchRequest(for:)`, `isMedicalPromptText(_:)`, `isClarifyingQuestion(_:)`) — unchanged, just relocated. `ConversationViewModel` (Task 4) will call these.

This is a pure move with no behavior change, matching the project convention of one type per file (`Models/Helpers/` already holds `ModelConfiguration.swift`, `ModelResponseType.swift`, `AppLanguageModel.swift`, etc.).

- [ ] **Step 1: Create the new file with the moved enum**

Copy `enum MedicalPromptAnalyzer { ... }` verbatim from `ChatView.swift` (currently lines 604–753) into a new file:

```swift
//
//  MedicalPromptAnalyzer.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/02/2026.
//

import Foundation

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
```

- [ ] **Step 2: Remove the moved enum from `ChatView.swift`**

Delete the `enum MedicalPromptAnalyzer { ... }` block (currently lines 604–753) from `itsWritten/Views/Chat/ChatView.swift`. Leave everything else in that file untouched for now — it gets fully superseded and deleted in Task 8.

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild build -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'generic/platform=iOS Simulator'`
Expected: `** BUILD SUCCEEDED **`

---

### Task 3: `ConversationViewModel` core (mode, session lifecycle, resume, reset)

**Files:**
- Create: `itsWritten/Models/ConversationViewModel.swift`
- Test: `itsWrittenTests/ConversationViewModelTests.swift`

**Interfaces:**
- Consumes: `ChatMessage`, `ChatThread` (existing), `ModelConfiguration` (existing, `Models/Helpers/ModelConfiguration.swift`), `AppLanguageModel` (existing), `PubMedToolStore`, `CrossPromoSignal` (existing).
- Produces (used by later tasks):
  - `ConversationViewModel.Mode` enum: `.composing`, `.chatting`
  - `var mode: Mode` (read-only outside the type)
  - `var messages: [ChatMessage]` (read-only outside the type)
  - `var title: String` (read/write)
  - `var threadId: UUID?` (read-only outside the type)
  - `var session: LanguageModelSession` (read-only outside the type)
  - `var isResponding: Bool` (read-only outside the type)
  - `func configure(modelContext: ModelContext, pubMedStore: PubMedToolStore, crossPromoSignal: CrossPromoSignal)`
  - `func prewarmIdleSession(config: ModelConfiguration)`
  - `func rebuildSession(config: ModelConfiguration)`
  - `func resume(thread: ChatThread, config: ModelConfiguration)`
  - `func reset()`
  - `static func orderedMessages(from messages: [ChatMessage]) -> [ChatMessage]`

Message-sending/generation/autosave (`startConversation`, `sendMessage`, `generateAndSetTitle`, and the `append`/`isRefusalMessage` internal helpers other tasks and tests touch) are added in Task 4 — this task only covers the state machine and session/thread lifecycle, which is independently testable without any FoundationModels network/on-device calls.

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:itsWrittenTests/ConversationViewModelTests`
Expected: FAIL — `ConversationViewModel` doesn't exist yet.

- [ ] **Step 3: Create `ConversationViewModel.swift` with the core state machine**

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:itsWrittenTests/ConversationViewModelTests`
Expected: PASS (all three tests)

---

### Task 4: `ConversationViewModel` message sending, generation, and autosave

**Files:**
- Modify: `itsWritten/Models/ConversationViewModel.swift`
- Modify: `itsWrittenTests/ConversationViewModelTests.swift`

**Interfaces:**
- Consumes: `MedicalPromptAnalyzer` (Task 2), `PubMedSearchTool`, `PubMedSearchError`, `PubMedEvidenceBundle`, `PubMedSearchRequest` (existing, `Tools/PubMedSearchTool.swift`), `ModelResponseType` (existing), everything from Task 3.
- Produces (used by Task 5, 6):
  - `func startConversation(with prompt: String, config: ModelConfiguration, responseType: ModelResponseType)`
  - `func sendMessage(_ prompt: String, config: ModelConfiguration, responseType: ModelResponseType)`
  - `func generateAndSetTitle(from prompt: String) async`
  - `func append(_ message: ChatMessage)` (internal, not private — exposed so tests can drive autosave directly without needing a live FoundationModels call)
  - `func isRefusalMessage(_ content: String) -> Bool` (internal, not private — pure string logic, testable without FoundationModels)

This is a near-verbatim port of `ChatView`'s message-send/streaming/refusal-recovery/session-compaction logic (currently `itsWritten/Views/Chat/ChatView.swift:85-591`), restructured onto the view model with two behavior changes called out explicitly:

1. **Autosave replaces `onDisappear`-triggered save.** There's no "disappear" event once chat is inline (mode just flips back to `.composing` in place), so every `append(_:)` call persists immediately: the `ChatThread` is inserted on the very first message, and updated on every subsequent one. This is strictly more robust than before (today, an app kill mid-conversation before the sheet is dismissed loses the whole thread).
2. **Title generation no longer blocks or shows an error alert.** It now runs in the background after the conversation is already visible (see Task 6), so a failure just leaves the "New Conversation" placeholder instead of interrupting the user — this is why `generateAndSetTitle` swallows errors instead of throwing.

- [ ] **Step 1: Write the failing tests**

Append these to `itsWrittenTests/ConversationViewModelTests.swift`:

```swift
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

        viewModel.reset()
        viewModel.title = "Second Thread"
        viewModel.append(ChatMessage(content: "Hello again", isUser: true))

        let fetched = try context.fetch(FetchDescriptor<ChatThread>())
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(Set(fetched.map(\.title)), Set(["First Thread", "Second Thread"]))
    }
```

Note: `import SwiftData` needs to be added to the top of the test file alongside the existing `import FoundationModels` and `import XCTest`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:itsWrittenTests/ConversationViewModelTests`
Expected: FAIL — `isRefusalMessage`/`append` don't exist yet.

- [ ] **Step 3: Add the message-sending/generation/autosave extension to `ConversationViewModel.swift`**

Append this extension to the bottom of `itsWritten/Models/ConversationViewModel.swift` (after the closing brace of the `ConversationViewModel` class):

```swift
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
        let instructions = """
        Summarize the prompt into a short title of 5 to 8 words.
        DO NOT use tools, lists, markdown, numbering, or quotes.
        Return only the title text.
        """
        let titleSession = AppLanguageModel.sessionWithoutTools(instructions: instructions)

        guard let generated = try? await lastStreamedContent(from: titleSession, prompt: prompt) else { return }

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

        Task {
            switch responseType {
            case .standard: await generateStandardResponse(for: resolvedPrompt, config: config)
            case .streaming: await generateStreamingResponse(for: resolvedPrompt, config: config)
            case .human: await generateHumanResponse(for: resolvedPrompt, config: config)
            }
        }
    }

    /// Generates a response using the standard (non-streaming) approach. Handles
    /// context window overflow by compacting the session and retrying.
    private func generateStandardResponse(for prompt: String, config: ModelConfiguration) async {
        isResponding = true
        defer { isResponding = false }

        let response = await generateResponseWithRecovery(for: prompt, config: config)
        if let response {
            append(makeAssistantMessage(from: response))
        } else {
            appendRecoveryFailureMessage()
        }
    }

    /// Generates a response using streaming, updating the UI as tokens arrive. Handles
    /// context window overflow by compacting and retrying.
    private func generateStreamingResponse(for prompt: String, config: ModelConfiguration) async {
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
                append(makeAssistantMessage(from: response, id: messageId, timestamp: timestamp))
                return
            case .prompt(let preparedPrompt):
                for try await partial in session.streamResponse(to: preparedPrompt, options: config.generationOptions) {
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
            if isRefusalMessage(response.content), let recovered = await recoverAfterFailure(for: prompt, config: config) {
                replaceStreamedMessage(
                    at: &messageIndex,
                    with: makeAssistantMessage(from: recovered, id: messageId, timestamp: timestamp)
                )
            } else if isRefusalMessage(response.content) {
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
            if let recovered = await recoverAfterFailure(for: prompt, config: config) {
                replaceStreamedMessage(
                    at: &messageIndex,
                    with: makeAssistantMessage(from: recovered, id: messageId, timestamp: timestamp)
                )
            } else {
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
    private func generateHumanResponse(for prompt: String, config: ModelConfiguration) async {
        let startTime = ContinuousClock.now

        do {
            try await Task.sleep(for: .seconds(2))
            isResponding = true

            guard let response = await generateResponseWithRecovery(for: prompt, config: config) else {
                appendRecoveryFailureMessage()
                isResponding = false
                return
            }
            let simulatedTime = Duration.seconds(1 + Double(response.content.count) * 0.02)

            if ContinuousClock.now - startTime < simulatedTime {
                try await Task.sleep(for: simulatedTime - (.now - startTime))
            }

            append(makeAssistantMessage(from: response))
        } catch {
            appendErrorMessage()
        }

        isResponding = false
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
    private func persistCurrentTurn() {
        guard let modelContext else { return }

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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:itsWrittenTests/ConversationViewModelTests`
Expected: PASS (all tests, including the three from Task 3)

- [ ] **Step 5: Build the whole project to verify it still compiles**

Run: `xcodebuild build -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'generic/platform=iOS Simulator'`
Expected: `** BUILD SUCCEEDED **` (`ChatView.swift` still exists and still compiles independently at this point — it's only removed in Task 8)

---

### Task 5: `ChatConversationView` (chat-mode UI)

**Files:**
- Create: `itsWritten/Views/Chat/ChatConversationView.swift`

**Interfaces:**
- Consumes: `ConversationViewModel` (Task 3/4, via `@Environment`), `HomeViewModel` (existing, via `@Environment`), `MessageListView` (Task 1), `PromptInputView` (existing, unchanged).
- Produces: `ChatConversationView(config: Binding<ModelConfiguration>, responseType: Binding<ModelResponseType>)` — used by `HomeContentView` in Task 6.

This replaces `ChatView`'s body (minus its own `NavigationStack` and the `Text(title)` header, which becomes `.navigationTitle` since this view now lives directly in `HomeView`'s existing stack).

- [ ] **Step 1: Create the file**

```swift
//
//  ChatConversationView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 09/08/2026.
//

import SwiftUI

struct ChatConversationView: View {
    @Environment(ConversationViewModel.self) private var viewModel
    @Environment(HomeViewModel.self) private var homeViewModel

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType

    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(
                messages: viewModel.messages,
                isResponding: viewModel.isResponding
            )

            PromptInputView(
                text: $input,
                placeholder: homeViewModel.placeholderText,
                isDisabled: viewModel.isResponding,
                onSubmit: sendMessage
            )
        }
        .navigationTitle(viewModel.title)
        .onChange(of: config.instructions) {
            viewModel.rebuildSession(config: config)
        }
    }

    private func sendMessage() {
        guard input.isReallyEmpty == false else { return }
        let prompt = input
        input = ""
        viewModel.sendMessage(prompt, config: config, responseType: responseType)
    }
}

#Preview {
    NavigationStack {
        ChatConversationView(
            config: .constant(ModelConfiguration()),
            responseType: .constant(.standard)
        )
    }
    .environment(ConversationViewModel())
    .environment(HomeViewModel())
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'generic/platform=iOS Simulator'`
Expected: `** BUILD SUCCEEDED **` (this file isn't referenced by anything yet, so it just needs to compile standalone)

---

### Task 6: `ComposingView`, restructured `HomeContentView`, and `HomeView` wiring

**Files:**
- Create: `itsWritten/Views/Home/ComposingView.swift`
- Modify: `itsWritten/Views/Home/HomeContentView.swift` (full rewrite of the body/init)
- Modify: `itsWritten/Views/Home/HomeView.swift`

**Interfaces:**
- Consumes: `ConversationViewModel` (Task 3/4), `ChatConversationView` (Task 5), `HomeTextEditor`, `HomeFooterView`, `CountdownView`, `CrossPromoBannerView` (all existing, unchanged), `AlertType` (existing).
- Produces: `HomeContentView(config: Binding<ModelConfiguration>, responseType: Binding<ModelResponseType>)` — note the signature drops the old `shouldSend: Binding<Bool>` and `session: LanguageModelSession` parameters (see rationale below); `HomeView` is updated in the same task since neither file compiles without the other.

This is one task, not three, because `ComposingView`, `HomeContentView`, and `HomeView`'s call site are inherently coupled for compilation — `HomeContentView`'s new signature only makes sense once `HomeView` is updated to match, and splitting them would leave an intermediate state that doesn't build.

Two simplifications bundled into this task, both enabled directly by the refactor (not scope creep):
- The old `shouldSend` `Binding<Bool>` + `.task(id: shouldSend)` dance in `HomeContentView`/`HomeView` existed only to trigger an async send from a synchronous button closure. That's unnecessary — a button action can just kick off `Task { await performSend() }` directly. Removed, replaced with an internal `isSending` guard in `HomeContentView` to prevent double-submission (which the old `shouldSend` boolean-flag pattern incidentally provided).
- The `RespondingIndicator` overlay shown in the composer while waiting on title generation no longer has anything meaningful to show: sending now switches to chat mode immediately (see Task 4's `startConversation`), before title generation is even awaited, so the composer screen is gone by the time there'd be anything to overlay. Removed from `ComposingView`.

- [ ] **Step 1: Create `ComposingView.swift`**

```swift
//
//  ComposingView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 09/08/2026.
//

import SwiftUI

struct ComposingView: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel
    @Environment(ConversationViewModel.self) private var viewModel

    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let sendAction: () -> Void

    var body: some View {
        VStack {
            HomeTextEditor(
                text: $text,
                isFocused: $isFocused,
                placeholderText: homeViewModel.placeholderText,
                isResponding: viewModel.session.isResponding
            )
            #if !DEBUG
            .hideSensitiveData()
            #endif
            if countDownViewModel.timerActive || countDownViewModel.timerPaused {
                CountdownView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                // Hidden while composing: keeps the ad out of the way of the keyboard, and
                // avoids reasoning about how an ad's own internal animations interact with
                // the keyboard-driven layout of this safeAreaInset.
                if isFocused == false {
                    CrossPromoBannerView()
                }

                HomeFooterView(
                    text: text,
                    isResponding: viewModel.session.isResponding,
                    sendAction: sendAction
                )
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            ComposingView(text: $text, isFocused: $isFocused, sendAction: {})
        }
    }
    return PreviewWrapper()
        .environment(HomeViewModel())
        .environment(CountdownViewModel())
        .environment(ConversationViewModel())
        .environment(RemoveAdsStore())
}
```

Note: `.environment(RemoveAdsStore())` is required here because `CrossPromoBannerView` (rendered inside `ComposingView`) reads it — omitting it crashes Xcode's canvas preview (the real app is unaffected since `itsWrittenApp.swift` injects it at the root).

- [ ] **Step 2: Rewrite `HomeContentView.swift`**

```swift
//
//  HomeContentView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import FoundationModels
import SwiftUI

struct HomeContentView: View {
    @Environment(ConversationViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel

    @FocusState private var isFocused: Bool
    @State private var text = ""
    @State private var activeAlert: AlertType?
    @State private var isSending = false

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType

    var body: some View {
        Group {
            switch viewModel.mode {
            case .composing:
                ComposingView(text: $text, isFocused: $isFocused, sendAction: sendButtonTapped)
            case .chatting:
                ChatConversationView(config: $config, responseType: $responseType)
            }
        }
        .animation(.default, value: viewModel.mode)
        .alert(activeAlert?.title ?? "", isPresented: .init(
            get: { activeAlert != nil },
            set: { if !$0 { activeAlert = nil } }
        )) {
            Button(activeAlert?.buttonText ?? "OK") {
                activeAlert = nil
            }
        } message: {
            Text(activeAlert?.message ?? "")
        }
        .onChange(of: countDownViewModel.timerExpired) { _, expired in
            if expired {
                activeAlert = .timeUp
            }
        }
    }

    private func sendButtonTapped() {
        Task { await performSend() }
    }

    @MainActor
    private func performSend() async {
        guard isSending == false else { return }
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }

        isSending = true
        defer { isSending = false }

        isFocused = false
        activeAlert = nil
        text = ""

        viewModel.startConversation(with: prompt, config: config, responseType: responseType)
        await viewModel.generateAndSetTitle(from: prompt)
    }
}

#Preview {
    HomeContentView(
        config: .constant(ModelConfiguration()),
        responseType: .constant(.standard)
    )
    .environment(HomeViewModel())
    .environment(CountdownViewModel())
    .environment(ConversationViewModel())
    .environment(RemoveAdsStore())
}
```

Note: same `RemoveAdsStore` requirement as `ComposingView`'s preview above — `HomeContentView` renders `ComposingView` (which needs it) whenever `mode == .composing`, the default.

- [ ] **Step 3: Update `HomeView.swift`**

```swift
//
//  HomeView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import PrivateAds
import SwiftData
import SwiftUI

struct HomeView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(HomeViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel
    @Environment(CrossPromoSignal.self) private var crossPromoSignal
    @Environment(RemoveAdsStore.self) private var removeAdsStore
    @Environment(PubMedToolStore.self) private var pubMedStore
    @Environment(\.modelContext) private var modelContext

    @State private var config = ModelConfiguration()
    @State private var responseType = ModelResponseType.standard
    @State private var presentedSheet: SheetType?
    @State private var conversationViewModel = ConversationViewModel()
    @State private var showChatHistoryView = false
    @State private var interstitialAd: Ad?
    @State private var isInterstitialPending = false

    var body: some View {
        NavigationStack {
            HomeContentView(
                config: $config,
                responseType: $responseType
            )
            .toolbar {
                if conversationViewModel.mode == .chatting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("New Chat", systemImage: "plus", action: conversationViewModel.reset)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarMenu
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                sheet.view
            }
            .onAppear {
                conversationViewModel.configure(
                    modelContext: modelContext,
                    pubMedStore: pubMedStore,
                    crossPromoSignal: crossPromoSignal
                )
                conversationViewModel.prewarmIdleSession(config: config)
            }
            .navigationDestination(isPresented: $showChatHistoryView) {
                ChatHistoryView(
                    config: $config,
                    responseType: $responseType
                )
            }
        }
        .environment(conversationViewModel)
        // A PrivateAds cross-promo ad every 3rd new chat started (see `CrossPromoSignal`,
        // bumped from `ConversationViewModel.persistCurrentTurn` when a brand-new thread is
        // first saved). The interstitial waits for the user to return to the composer
        // (`mode == .composing`) before showing, so it never interrupts an in-progress
        // conversation.
        .fullScreenCover(item: $interstitialAd) { ad in
            AdView(advert: ad, config: .crossPromo) {
                CrossPromoRemoveAdsInfoView()
            }
        }
        .onChange(of: crossPromoSignal.count) { _, newValue in
            guard removeAdsStore.isAdsRemoved == false, newValue > 0, newValue.isMultiple(of: 3) else { return }
            isInterstitialPending = true
        }
        .onChange(of: conversationViewModel.mode) { _, newMode in
            guard newMode == .composing, isInterstitialPending else { return }
            isInterstitialPending = false
            Task { await refreshInterstitialAd() }
        }
        // Dismiss an ad the user is mid-way through if they buy "Remove Ads" from its own paywall.
        .onChange(of: removeAdsStore.isAdsRemoved) { _, isAdsRemoved in
            guard isAdsRemoved else { return }
            interstitialAd = nil
        }
    }

    private func refreshInterstitialAd() async {
        guard removeAdsStore.isAdsRemoved == false else { return }
        guard let url = AdConfiguration.crossPromo.adsJSONURL else { return }
        interstitialAd = try? await AdStore.fetchRandomAd(
            from: url,
            excludedIDs: AdConfiguration.crossPromo.excludedIDs
        )
    }

    private var toolbarMenu: some View {
        GlassEffectContainer {
            MenuButtonView(
                showWhyAISheet: .init(
                    get: { presentedSheet == .whyAI },
                    set: { if $0 { presentedSheet = .whyAI } else { presentedSheet = nil } }
                ),
                showChatHistoryView: $showChatHistoryView,
                showSettings: .init(
                    get: { presentedSheet == .settings($config, $responseType) },
                    set: {
                        if $0 {
                            presentedSheet = .settings($config, $responseType)
                        } else {
                            presentedSheet = nil
                        }
                    }
                ),
                showOnboarding: {
                    presentedSheet = nil
                    hasCompletedOnboarding = false
                }
            )
        }
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
        .environment(CountdownViewModel())
        .environment(CrossPromoSignal())
        .environment(RemoveAdsStore())
        .environment(PubMedToolStore.shared)
        .modelContainer(for: [ChatThread.self, ChatMessage.self], inMemory: true)
}
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild build -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'generic/platform=iOS Simulator'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Manually verify in the Simulator**

1. Launch the app, type a message, tap send. Confirm the screen switches to the chat thread immediately (no sheet slides up), and the nav title updates from "New Conversation" to the generated title a moment later.
2. Send a follow-up message; confirm it streams in and the thread stays scrolled to the bottom (Task 1's fix still holds in this new context).
3. Tap "New Chat" in the toolbar. Confirm it animates back to the empty composer in place (no navigation push/pop).
4. Send several new chats in a row and confirm a cross-promo interstitial still appears the next time you return to the composer after the 3rd one (best-effort spot check — timing depends on ad availability).

---

### Task 7: `ChatHistoryView` resumes into the shared view model

**Files:**
- Modify: `itsWritten/Views/Chat/ChatHistoryView.swift`

**Interfaces:**
- Consumes: `ConversationViewModel.resume(thread:config:)` (Task 3), via `@Environment` (already injected by `HomeView` in Task 6, and propagates automatically to this view since it's pushed onto the same `NavigationStack`).

- [ ] **Step 1: Update the file**

Replace `itsWritten/Views/Chat/ChatHistoryView.swift` in full:

```swift
//
//  ChatHistoryView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 28/01/2026.
//

import FoundationModels
import SwiftUI
import SwiftData

struct ChatHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ConversationViewModel.self) private var conversationViewModel
    @Query(sort: \ChatThread.lastUpdated, order: .reverse) private var chatThreads: [ChatThread]

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType
    @State private var showingDeleteAllConfirmation = false

    var body: some View {
        Group {
            if chatThreads.isEmpty {
                unavailableView
            } else {
                availableView
                    #if !DEBUG
                    .hideSensitiveData()
                    #endif
            }
        }
        .safeAreaInset(edge: .bottom) {
            CrossPromoBannerView()
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete All") {
                    showingDeleteAllConfirmation = true
                }
                .disabled(chatThreads.isEmpty)
                .confirmationDialog(
                    "Delete all history?",
                    isPresented: $showingDeleteAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) {
                        withAnimation(.easeInOut) {
                            for thread in chatThreads {
                                modelContext.delete(thread)
                            }
                            try? modelContext.save()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently remove all saved conversations.")
                }
            }
        }
    }

    var unavailableView: some View {
        ContentUnavailableView {
            Label("No History", systemImage: "bubble.left.and.exclamationmark.bubble.right")
        } description: {
            Text("You don't have any conversation history yet")
        }
    }

    var availableView: some View {
        List {
            ForEach(chatThreads) { thread in
                Button(action: {
                    conversationViewModel.resume(thread: thread, config: config)
                    dismiss()
                }) {
                    ChatHistoryRowView(thread: thread)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteThreads)
        }
        .listStyle(.plain)
    }

    private func deleteThreads(at offsets: IndexSet) {
        withAnimation(.easeInOut) {
            for index in offsets {
                modelContext.delete(chatThreads[index])
            }
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        ChatHistoryView(
            config: .constant(ModelConfiguration()),
            responseType: .constant(.standard)
        )
    }
    .environment(RemoveAdsStore())
    .environment(ConversationViewModel())
    .modelContainer(for: [ChatThread.self, ChatMessage.self], inMemory: true)
}
```

Note this drops the `NavigationStack` that used to wrap this view's own body (it no longer presents its own sheet with its own nested stack) and the `responseType` param, while still accepted for `ConversationViewModel.resume`/future use by the caller, is no longer read directly inside this file — that's expected, since `resume(thread:config:)` only needs `config` (it rebuilds the session from the saved transcript, not the live response-generation mode).

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'generic/platform=iOS Simulator'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manually verify in the Simulator**

1. Start and complete a couple of chats so they show up in History.
2. Open the menu → History, tap a saved thread. Confirm it dismisses History and shows that thread inline (title, prior messages, scrolled to bottom) on the same screen you started from — no sheet.
3. Send a follow-up message in the resumed thread and confirm it updates the same saved `ChatThread` (open History again afterward and confirm there's still only one entry for it, not a duplicate).

---

### Task 8: Final cleanup — remove superseded sheet-based chat code

**Files:**
- Delete: `itsWritten/Views/Chat/ChatView.swift`
- Modify: `itsWritten/Views/Home/SheetType.swift` (remove `.chat` case)
- Modify: `itsWritten/Helpers/AlertType.swift` (remove now-dead `.aiGeneration` case and `aiGenerationAlert(for:)`, confirmed unused by grep below)

**Interfaces:** None — this only removes code nothing references anymore after Tasks 6–7.

- [ ] **Step 1: Confirm nothing still references the code being removed**

Run: `grep -rn "SheetType.chat\|case .chat\|ChatView(" "/Users/filippocilia/Desktop/Projects/iOS/itsWritten/itsWritten"`
Expected: no matches outside of `SheetType.swift`'s own definition (which this task removes next) and `ChatView.swift` itself (which this task deletes).

Run: `grep -rn "aiGenerationAlert\|AlertType.aiGeneration\|case aiGeneration" "/Users/filippocilia/Desktop/Projects/iOS/itsWritten/itsWritten"`
Expected: only matches inside `AlertType.swift` itself — confirms `HomeContentView`'s old catch block (removed in Task 6) was the only caller.

- [ ] **Step 2: Delete `ChatView.swift`**

Run: `rm "/Users/filippocilia/Desktop/Projects/iOS/itsWritten/itsWritten/Views/Chat/ChatView.swift"`

Also remove it from the Xcode project if it doesn't clean up automatically (open `itsWritten.xcodeproj` in Xcode, or if using file-system-synchronized groups this is automatic — verify with the build in Step 5 either way).

- [ ] **Step 3: Remove the `.chat` case from `SheetType.swift`**

```swift
//
//  SheetType.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import Foundation
import FoundationModels
import SwiftUI

enum SheetType: Identifiable, Equatable {
    case whyAI
    case settings(Binding<ModelConfiguration>, Binding<ModelResponseType>)

    var id: String {
        switch self {
        case .whyAI:
            return "whyAI"
        case .settings:
            return "settings"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .whyAI:
            WhyAIView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)

        case .settings(let config, let responseType):
            NavigationStack {
                ModelSettingsSheet(
                    configuration: config,
                    responseType: responseType
                )
            }
            .background(.ultraThinMaterial)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    static func == (lhs: SheetType, rhs: SheetType) -> Bool {
        return lhs.id == rhs.id
    }
}
```

- [ ] **Step 4: Remove the dead `.aiGeneration` case from `AlertType.swift`**

```swift
//
//  AlertType.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import Foundation

enum AlertType: Identifiable {
    case timeUp

    var id: String {
        switch self {
        case .timeUp:
            return "timeUp"
        }
    }

    var title: String {
        switch self {
        case .timeUp:
            return "Time's Up!"
        }
    }

    var message: String {
        switch self {
        case .timeUp:
            return "Your countdown timer has finished."
        }
    }

    var buttonText: String {
        "OK"
    }
}
```

Note the `import FoundationModels` and the `aiGenerationAlert(for:)` extension are both removed along with the case — the file no longer needs FoundationModels at all once the only `LanguageModelSession.GenerationError`-handling code is gone.

- [ ] **Step 5: Full build and full test run**

Run: `xcodebuild build -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'generic/platform=iOS Simulator'`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project "itsWritten.xcodeproj" -scheme itsWritten -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: all tests pass, including the existing `AlertTypeTests.swift` — check it first, since it's the one existing test file this task's changes could break:

Run: `grep -n "aiGeneration" "/Users/filippocilia/Desktop/Projects/iOS/itsWritten/itsWrittenTests/AlertTypeTests.swift"`
If this returns matches, update or remove those specific test cases (they'd be testing the now-deleted `.aiGeneration` case/`aiGenerationAlert(for:)` method) before re-running the full test suite.

- [ ] **Step 6: Full manual regression pass in the Simulator**

Walk through the complete flow end to end once more, now that all sheet-based chat code is gone:
1. New chat from the composer → inline transition → title fills in → streaming response → autoscroll holds through several exchanges.
2. New Chat button resets in place.
3. Chat History → resume a thread → inline, scrolled to bottom, follow-up messages update the same thread (not a duplicate).
4. Settings and "Why AI?" still open as sheets exactly as before (unchanged in this plan).
5. Countdown timer expiring still shows its alert while composing.
6. Force-quit the Simulator app mid-response on a brand-new chat, relaunch, open Chat History — confirm the user's prompt (and any messages already completed) were saved, since autosave no longer depends on a dismiss event.

**Known limitation to flag once this plan is complete:** the spec's testing section also called for coverage of "transcript compaction / refusal-recovery behavior." `isRefusalMessage` is covered directly (Task 4), but `compactedSessionFromMessages` isn't — it returns a live `LanguageModelSession` built from a `Transcript`, and this codebase has no existing seam for inspecting `Transcript` contents or mocking FoundationModels calls in tests (no test in the project today calls `.respond`/`.streamResponse`). Building that seam would be a separate, larger effort and is out of scope here.
