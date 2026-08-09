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
