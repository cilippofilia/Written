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
    @State private var scrollPosition: AnyHashable?
    @State private var isAtBottom = true

    private let typingIndicatorID = "typing-indicator"
    private var showsTypingIndicator: Bool {
        guard isResponding else { return false }
        guard let lastMessage = messages.last else { return true }
        return lastMessage.isUser || lastMessage.content.isReallyEmpty
    }

    var body: some View {
        ScrollViewReader { proxy in
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
            .scrollPosition(id: $scrollPosition)
            .onChange(of: scrollPosition) { _, newValue in
                updateIsAtBottom(newValue)
            }
            .onChange(of: messages.count) {
                scrollToBottomIfNeeded(proxy: proxy)
            }
            .onChange(of: messages.last?.content) {
                scrollToBottomIfNeeded(proxy: proxy)
            }
            .onChange(of: isResponding) {
                scrollToBottomIfNeeded(proxy: proxy)
            }
        }
    }

    /// Scrolls the view to show the most recent content.
    /// - Parameter proxy: The scroll view proxy used to perform the scroll.
    func scrollToBottomIfNeeded(proxy: ScrollViewProxy) {
        guard isAtBottom else { return }
        if showsTypingIndicator {
            proxy.scrollTo(typingIndicatorID, anchor: .bottom)
        } else if let lastMessage = messages.last {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    func updateIsAtBottom(_ newValue: AnyHashable?) {
        guard let newValue else { return }
        if showsTypingIndicator {
            isAtBottom = newValue == AnyHashable(typingIndicatorID)
        } else if let lastMessage = messages.last {
            isAtBottom = newValue == AnyHashable(lastMessage.id)
        }
    }
}

#Preview {
    MessageListView(messages: [], isResponding: false)
}
