//
//  ChatModel.swift
//  itsWritten
//
//  Created by Filippo Cilia on 28/01/2026.
//

import Foundation
import SwiftData

struct ChatModel: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    let title: String
    let prompt: String
    let response: String
    var creationDate = Date()
}

struct ChatMessageSource: Codable, Hashable, Identifiable {
    let title: String
    let pmid: String
    let url: String

    var id: String {
        "\(pmid)-\(url)"
    }
}

/// Represents a single message in a chat conversation.
@Model
final class ChatMessage: Identifiable {
    @Attribute(.unique) var id: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date
    var toolNames: [String]
    var toolSources: [ChatMessageSource]

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = .now,
        toolNames: [String] = [],
        toolSources: [ChatMessageSource] = []
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.toolNames = toolNames
        self.toolSources = toolSources
    }
}

/// The type of response generation to use.
enum ResponseType: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case streaming = "Streaming"
    case human = "Human"

    var id: Self { self }
}
