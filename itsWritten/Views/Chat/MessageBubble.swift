//
//  MessageBubble.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/02/2026.
//

import SwiftUI

/// Displays a single chat message in a bubble style.
///
/// User messages appear with a blue background aligned to the trailing edge,
/// while AI responses appear with a gray background aligned to the leading edge.
struct MessageBubble: View {
    @State private var discloseToolsUsed: Bool = false

    let message: ChatMessage

    var body: some View {
        let frameAlignment = message.isUser ? Alignment.trailing : .leading
        let contentAlignment = message.isUser ? HorizontalAlignment.trailing : .leading

        VStack(alignment: contentAlignment, spacing: 6) {
            FormattedMessageText(text: message.content)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .background(message.isUser ? Color.blue.gradient : Color.gray.opacity(0.2).gradient)
                .foregroundStyle(message.isUser ? Color.white : Color.primary)
                .clipShape(.rect(cornerRadius: 18))

            if message.isUser == false, message.toolNames.isEmpty == false || message.toolSources.isEmpty == false {
                Button {
                    discloseToolsUsed.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.forward")
                            .imageScale(.small)
                            .rotationEffect(.degrees(discloseToolsUsed ? 90 : 0), anchor: .center)

                        Text("Tools used")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .font(.caption)

                if discloseToolsUsed {
                    VStack(alignment: .leading, spacing: 8) {
                        if message.toolNames.isEmpty == false {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.toolNames.joined(separator: ", "))
                                    .font(.caption)
                                    .bold()
                            }
                        }

                        if message.toolSources.isEmpty == false {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(message.toolSources) { source in
                                    ToolSourceRow(source: source)
                                }
                            }
                        }
                    }
                }
            }
        }
        .containerRelativeFrame(.horizontal, alignment: frameAlignment) { size, _ in
            size * 0.75
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }
}

#Preview("User message - Light") {
    MessageBubble(message: ChatMessage(content: "This is my message as a response to the previous one.", isUser: true))
}
#Preview("AI response - Light") {
    MessageBubble(message: ChatMessage(content: "This is my message as a response to the previous one.", isUser: false))
}
#Preview("User message - Dark") {
    MessageBubble(message: ChatMessage(content: "This is my message as a response to the previous one.", isUser: true))
        .preferredColorScheme(.dark)
}
#Preview("AI response - Dark") {
    MessageBubble(
        message: ChatMessage(
            content: "This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.This is my message as a response to the previous one.",
            isUser: false,
            toolNames: ["PubMed"],
            toolSources: [
                ChatMessageSource(
                    title: "Sleep Quality and Adolescents",
                    pmid: "12345678",
                    url: "https://pubmed.ncbi.nlm.nih.gov/12345678/"
                )
            ]
        )
    )
        .preferredColorScheme(.dark)
}

private struct ToolSourceRow: View {
    let source: ChatMessageSource

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(source.title)
                .font(.caption)
                .bold()

            Text("PMID: \(source.pmid)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let url = URL(string: source.url) {
                Link(source.url, destination: url)
                    .font(.caption2)
            }
        }
        .foregroundStyle(.secondary)
    }
}
