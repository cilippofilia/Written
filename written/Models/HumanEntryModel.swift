//
//  HumanEntryModel.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import SwiftUI

struct HumanEntryModel: Identifiable {
    let id: UUID
    let date: String
    let filename: String
    var previewText: String

    static func createNew() -> HumanEntryModel {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: now)

        // For display
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)

        return HumanEntryModel(
            id: id,
            date: displayDate,
            filename: "[\(id)]-[\(dateString)].md",
            previewText: ""
        )
    }
}
