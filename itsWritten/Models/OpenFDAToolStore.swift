//
//  OpenFDAToolStore.swift
//  itsWritten
//
//  Created by Filippo Cilia on 25/05/2026.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class OpenFDAToolStore {
    static let shared = OpenFDAToolStore()

    struct DrugResult: Hashable {
        let brandName: String
        let genericName: String
        let url: String
    }

    private(set) var results: [DrugResult] = []
    private(set) var wasUsed = false

    func record(results: [DrugResult]) {
        self.results = results
        wasUsed = results.isEmpty == false
    }

    func reset() {
        results = []
        wasUsed = false
    }
}
