//
//  PromptModel.swift
//  Written
//
//  Created by Filippo Cilia on 07/01/2026.
//

import Foundation

public struct PromptModel: Codable, Hashable {
    public var id: String
    public var title: String
    public var prompt: String
}
