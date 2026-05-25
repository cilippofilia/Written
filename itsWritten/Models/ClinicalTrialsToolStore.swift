//
//  ClinicalTrialsToolStore.swift
//  itsWritten
//
//  Created by Filippo Cilia on 25/05/2026.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ClinicalTrialsToolStore {
    static let shared = ClinicalTrialsToolStore()

    struct Trial: Hashable {
        let title: String
        let nctId: String
        let url: String
        let status: String
    }

    private(set) var trials: [Trial] = []
    private(set) var wasUsed = false

    func record(trials: [Trial]) {
        self.trials = trials
        wasUsed = trials.isEmpty == false
    }

    func reset() {
        trials = []
        wasUsed = false
    }
}
