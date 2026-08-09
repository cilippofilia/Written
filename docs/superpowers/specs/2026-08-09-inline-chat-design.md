# Inline Chat Redesign — Design Spec

Date: 2026-08-09

## Problem

1. **Scroll bug:** In `MessageListView`, autoscroll silently stops working after a few
   messages. Root cause: `ScrollViewReader.scrollTo()` (imperative) and
   `.scrollPosition(id:)` (two-way binding) fight each other. During streaming, the last
   bubble's height keeps changing mid-scroll, so the exact-id match used for `isAtBottom`
   can flip to `false` and never recover.
2. **Sheet-based chat UX:** Starting or resuming a chat currently opens `ChatView` as a
   `.sheet(item:)` from `HomeContentView` (new chats) or `ChatHistoryView` (resumed
   threads) — a fully separate view hierarchy with its own `NavigationStack`, state, and
   session. This is the same underlying `MessageListView` scroll bug, but presenting the
   chat inline (in the same screen the user started typing in) is a better UX in its own
   right and worth doing regardless of the scroll fix.

This spec covers both, as two independent tracks: Track 1 (scroll fix) ships on its own;
Track 2 (inline chat) is the larger refactor.

## Track 1 — Scroll fix (MessageListView)

Replace `ScrollViewReader` + `.scrollPosition(id:)` with the iOS 18+
`ScrollPosition(edge: .bottom)` type and the `.scrollPosition($scrollPosition)` modifier,
which is purpose-built for "pinned to bottom unless the user scrolled away" chat-log
behavior and avoids the read/write duality of the current approach.

Replace the exact-id `isAtBottom` heuristic with `.onScrollGeometryChange(for: Bool.self)`,
computing "near bottom" from real scroll geometry (`contentOffset`, `contentSize`,
`containerSize`) instead of matching against the last message's id.

Scope: `Views/Chat/MessageListView.swift` only. No other files change. Ships
independently of Track 2.

## Track 2 — Inline chat (no more `.sheet` for chat)

### Architecture

- **`ConversationViewModel`** (new, `@MainActor @Observable`, under `Models/`) — owned by
  `HomeView` as a single `@State` instance, injected into the environment (same pattern as
  `CrossPromoSignal`/`HomeViewModel`). Owns `mode: ConversationMode` (`.composing` /
  `.chatting`), `title`, `threadId`, `messages`, `session`, `isResponding`. Absorbs the
  message-send/streaming/session-compaction/refusal-recovery logic that currently lives
  directly on the `ChatView` struct as `@State`/methods.
  - Since it's a plain class, it cannot use `@Environment` itself. `modelContext`,
    `PubMedToolStore`, and `CrossPromoSignal` are handed to it explicitly (via init or
    method parameters) by `HomeView`, which already has access to them via `@Environment`.
  - `config`/`responseType` remain `Binding`s passed in from `HomeView`, as today.

- **Merged screen** (replaces today's `HomeContentView` body) — renders
  `HomeTextEditor` + `HomeFooterView` when `mode == .composing`, or the message list +
  `PromptInputView` when `mode == .chatting`, switching on `ConversationViewModel.mode`.
  The switch is wrapped in `withAnimation(.default)` for a crossfade/slide (no
  matched-geometry morph in this scope).
  - The chat title moves from an inline `Text(title)` (today's `ChatView`) to
    `.navigationTitle`, since this screen now lives directly in `HomeView`'s existing
    `NavigationStack` instead of a nested `NavigationStack` inside a sheet.

- **`SheetType`** loses its `.chat` case. It goes back to just `.whyAI` and `.settings`,
  unchanged in how they're presented (out of scope for this refactor).

- **`ChatView.swift`** as a standalone `View` goes away — its logic moves onto
  `ConversationViewModel`, its layout merges into the screen above.

- **`ChatHistoryView`** drops its own `presentedSheet`/`SheetType.chat` usage and instead
  reads the shared `ConversationViewModel` from the environment.

### Data flow — sending the first message

1. User taps Send in composer mode. Screen calls `viewModel.startConversation(with: text)`.
2. Synchronously: `mode = .chatting`, a fresh `session` is built from the current
   `config.instructions`, the user's `ChatMessage` is appended, composer text clears. The
   screen re-renders into chat layout immediately — no blocking on title generation.
3. Two `Task`s run in parallel:
   - **Response generation** — same streaming/standard/human logic as today's `ChatView`,
     now on the view model.
   - **Title generation** — same `generateTitle(from:)` call, no longer blocking the mode
     transition. When it resolves, `viewModel.title` updates and the nav bar title fills
     in (shows a placeholder, e.g. "New Conversation", until then).

### Data flow — autosave

Replaces the current `ChatView.onDisappear { saveThreadOnDismiss() }`, since there is no
"disappear" event when chat is inline (mode just flips back to `.composing` in place).

- The `ChatThread` is inserted into SwiftData as soon as the first user message is
  appended (title = placeholder until the title task resolves, then that field is
  updated on the persisted object).
- `messages` and `lastUpdated` are upserted after every completed assistant turn
  (streaming, standard, and human generation paths each already have one point where the
  finished assistant message is appended — that's the save hook).
- `New Chat` has nothing to flush; state is already durable at that point.

This is a behavior change from today (which only saves once, on sheet dismissal) and is
strictly more robust — an app kill mid-conversation no longer loses the whole thread.

### Error handling

Unchanged in substance, relocated onto the view model: context-window-overflow recovery
via `compactedSessionFromMessages` + retry, refusal-phrase detection/recovery, and
`activeAlert` surfaced for generation errors on the first send.

### Cross-promo interstitial rework

Today, `crossPromoSignal.bump()` fires inside `saveThreadOnDismiss()` the first time a
thread is newly created, and `HomeView` waits for `presentedSheet == nil` before
presenting the interstitial `fullScreenCover` (presenting it mid-dismissal can silently
no-op).

With autosave now firing on "first user message appended," the bump fires at the same
logical moment — unchanged. The deferral signal changes: `HomeView` waits for
`conversationViewModel.mode == .composing` again instead of `presentedSheet == nil`. In
practice, the interstitial shows the next time the user returns to the composer (taps
"New Chat") after crossing the 3rd-new-thread threshold — same "don't interrupt an
in-progress screen" intent as today, keyed off `mode` instead of sheet state.

### History resume (`ChatHistoryView`)

- Drops `presentedSheet`/`SheetType.chat`.
- Reads the shared `ConversationViewModel` via `@Environment`.
- Tapping a row calls `viewModel.resume(thread:)` — builds the session from the thread's
  saved transcript (same `buildSession(for:)` logic as today, moved onto the view model),
  sets `messages`, `threadId`, `title`, `mode = .chatting`.
- Calls `dismiss()` (it's a pushed `navigationDestination`, not a sheet) to pop back to
  `HomeView`'s root, which now renders the resumed conversation inline.

### New Chat button

Shown in the toolbar only when `mode == .chatting`. Calls `viewModel.reset()`: clears
`messages`, `threadId`, `title`, builds a fresh `session`, sets `mode = .composing`.
Resets in place — no navigation push/pop involved.

### Testing

Moving send/streaming/recovery/resume/reset logic onto `ConversationViewModel` makes it
unit-testable with Swift Testing, using an in-memory `ModelContainer` (existing
`#Preview` blocks already demonstrate this setup). Coverage to add:
- Transcript compaction / refusal-recovery behavior (already intricate today, currently
  untested).
- `resume(thread:)` correctly rehydrating state from a saved thread.
- `reset()` clearing all conversation state.
- Autosave upsert logic (new-thread insert vs. existing-thread update).

This closes the existing gap where this logic lives untestable inside a `View` struct,
in line with this project's convention of keeping view logic in testable view models.

## Out of scope

- `WhyAIView` and `ModelSettingsSheet` presentation — remain sheets, unchanged.
- Matched-geometry morph animation between composer and chat layouts (crossfade/slide
  only, for now).
- Any change to the medical-prompt analysis, PubMed tool integration, or generation
  strategies (standard/streaming/human) themselves — only *where* this logic lives
  changes, not its behavior.
